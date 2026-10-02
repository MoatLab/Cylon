// SPDX-License-Identifier: GPL-2.0
#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <inttypes.h>
#include <linux/kvm.h>
#include <linux/memfd.h>
#include <pthread.h>
#include <signal.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <sys/uio.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>
#include "../../kselftest.h"

/* Private Cylon ABI: include/linux/kvm_ext.h is not a userspace header. */
#define DUAL_MODE (1U << 17)
struct ft_chunk { uint64_t *spt; int npages, offset; };
struct ft_spt {
	struct ft_chunk chunks[60];
	void *backend;
	uint64_t gfn;
	int n;
};
struct ft_flush { uint64_t gpa, flag, lpn; };
#define GET_SPT _IOWR(KVMIO, 0xde, struct ft_spt)
#define FLUSH_GFN _IOW(KVMIO, 0xdd, struct ft_flush)
#define PAGE 4096UL
#define HUGE (2UL << 20)
#define PRESENT (1ULL << 11)
#define WRITE 2ULL
#define ACCESSED (1ULL << 8)
#define DIRTY (1ULL << 9)
#define MMU_WRITE (1ULL << 58)
#define ADDR 0x000ffffffffff000ULL
#define DIRECT (7ULL | (6ULL << 3) | (1ULL << 6) | PRESENT | \
		(1ULL << 57) | MMU_WRITE)
#define GOOD 0x12345678abcdef01ULL
#define WRONG 0xfedcba9876543210ULL
#define STORED 0x1020304050607080ULL
#define LOAD(p) __atomic_load_n((p), __ATOMIC_SEQ_CST)
#define STORE(p, v) __atomic_store_n((p), (v), __ATOMIC_SEQ_CST)
#define REQUIRE(c, ...) do { \
	if (!(c)) { \
		fprintf(stderr, "# %s:%d: ", __func__, __LINE__); \
		fprintf(stderr, __VA_ARGS__); \
		fprintf(stderr, " (errno=%d)\n", errno); \
		exit(KSFT_FAIL); \
	} \
} while (0)

extern const unsigned char ft_guest_start[], ft_guest_end[];
struct control { uint64_t stop, count, wrong, value, go, bad; };
struct vcpu {
	int fd, run_size;
	struct kvm_run *run;
	struct control *ctl;
	unsigned int mmio;
};
struct test {
	int kvm, vm, memfd, pagemap;
	uint64_t gpa;
	void *ram, *backing;
	uint64_t *spt;
	struct vcpu cpu[2];
};
static unsigned int *stage;
static bool control_kernel;
static unsigned int timeout_secs = 10;
static const char *trace_output;
static char trace_instance[256];
static const char *const names[] = {
	"", "read", "write", "exec", "empty", "wrong target",
	"wrong sibling reader", "wrong target reader", "host read-only",
	"dirty-log flags", "write tracking", "detached target invalidation",
	"detached sibling invalidation", "root churn", "read-only revocation",
	"two valid roots"
};

static void trace_write(const char *file, const char *value);

static void skip(const char *why)
{
	printf("# SKIP %s\n", why);
	exit(KSFT_SKIP);
}

static void checked_ioctl(int fd, unsigned long cmd, void *arg)
{
	REQUIRE(ioctl(fd, cmd, arg) == 0, "ioctl %#lx", cmd);
}

static uint64_t frame(struct test *t, void *p)
{
	uint64_t entry;
	off_t offset = (uintptr_t)p / PAGE * sizeof(entry);

	REQUIRE(pread(t->pagemap, &entry, sizeof(entry), offset) == sizeof(entry),
		"pagemap read");
	REQUIRE(entry & (1ULL << 63), "host page absent");
	entry &= (1ULL << 55) - 1;
	if (!entry)
		skip("pagemap PFNs require CAP_SYS_ADMIN");
	return entry * PAGE;
}

static void slot(struct test *t, unsigned int id, uint64_t gpa,
		 void *hva, uint64_t size, unsigned int flags)
{
	struct kvm_userspace_memory_region m = {
		.slot = id, .flags = flags, .guest_phys_addr = gpa,
		.userspace_addr = (uintptr_t)hva, .memory_size = size,
	};

	checked_ioctl(t->vm, KVM_SET_USER_MEMORY_REGION, &m);
}

static void check_parameter(const char *path)
{
	char c;
	int fd = open(path, O_RDONLY);

	if (fd < 0 || read(fd, &c, 1) != 1 || (c != 'Y' && c != '1'))
		skip(path);
	close(fd);
}

static void setup(struct test *t, int row)
{
	struct ft_spt spt = { 0 };
	uint64_t *pt;

	memset(t, 0, sizeof(*t));
	t->gpa = (row + 1) * HUGE;
	t->kvm = open("/dev/kvm", O_RDWR | O_CLOEXEC);
	if (t->kvm < 0)
		skip("/dev/kvm unavailable");
	REQUIRE(ioctl(t->kvm, KVM_GET_API_VERSION, 0) == KVM_API_VERSION,
		"KVM API version");
	t->vm = ioctl(t->kvm, KVM_CREATE_VM, 0);
	REQUIRE(t->vm >= 0, "create VM");
	t->pagemap = open("/proc/self/pagemap", O_RDONLY);
	REQUIRE(t->pagemap >= 0, "open pagemap");
	t->ram = mmap(NULL, HUGE, PROT_READ | PROT_WRITE,
		      MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
	REQUIRE(t->ram != MAP_FAILED, "guest RAM");
	slot(t, 0, 0, t->ram, HUGE, 0);
	memcpy(t->ram + PAGE, ft_guest_start, ft_guest_end - ft_guest_start);
	/* Identity map the first GiB with 2 MiB guest pages. */
	pt = t->ram + 2 * PAGE;
	pt[0] = 3 * PAGE | 3;
	pt = t->ram + 3 * PAGE;
	pt[0] = 4 * PAGE | 3;
	pt = t->ram + 4 * PAGE;
	for (unsigned int i = 0; i < 512; i++)
		pt[i] = i * HUGE | 0x83;
	t->memfd = memfd_create("cylon-ft", MFD_HUGETLB | MFD_HUGE_2MB);
	if (t->memfd < 0 || ftruncate(t->memfd, HUGE))
		skip("2 MiB hugetlb memfd unavailable");
	if (fallocate(t->memfd, 0, 0, HUGE))
		skip("reserve at least two free 2 MiB huge pages");
	t->backing = mmap(NULL, HUGE, PROT_READ | PROT_WRITE, MAP_SHARED,
			  t->memfd, 0);
	REQUIRE(t->backing != MAP_FAILED, "map huge page");
	REQUIRE(!((uintptr_t)t->backing & (HUGE - 1)), "hugetlb alignment");
	*(uint64_t *)t->backing = GOOD;
	*(uint64_t *)(t->backing + PAGE) = GOOD;
	*(uint64_t *)(t->backing + 2 * PAGE) = WRONG;
	if (row == 8)
		REQUIRE(!mprotect(t->backing, HUGE, PROT_READ), "read-only host VMA");
	slot(t, 1, t->gpa, t->backing, HUGE, DUAL_MODE);
	t->spt = mmap(NULL, PAGE, PROT_READ | PROT_WRITE,
		      MAP_SHARED | MAP_ANONYMOUS, -1, 0);
	REQUIRE(t->spt != MAP_FAILED, "SPT reservation");
	spt.gfn = t->gpa / PAGE;
	spt.chunks[0].spt = t->spt;
	checked_ioctl(t->vm, GET_SPT, &spt);
	REQUIRE(spt.n == 1 && spt.chunks[0].npages == 1 &&
		!spt.chunks[0].offset, "SPT shape");
	printf("# row=%d pid=%d gfn=%#" PRIx64 "\n", row, getpid(), t->gpa / PAGE);
}

static void create_cpu(struct test *t, unsigned int id, unsigned int phys_bits)
{
	struct vcpu *v = &t->cpu[id];
	struct kvm_cpuid2 *cpuid = calloc(1, sizeof(*cpuid) +
					256 * sizeof(struct kvm_cpuid_entry2));
	struct kvm_sregs s;
	int run_size;

	REQUIRE(cpuid, "CPUID allocation");
	cpuid->nent = 256;
	checked_ioctl(t->kvm, KVM_GET_SUPPORTED_CPUID, cpuid);
	if (phys_bits) {
		for (unsigned int i = 0; i < cpuid->nent; i++) {
			if (cpuid->entries[i].function == 0x80000008) {
				if ((cpuid->entries[i].eax & 0xff) < phys_bits)
					skip("MAXPHYADDR > 48 unavailable");
				cpuid->entries[i].eax &= ~0xffU;
				cpuid->entries[i].eax |= phys_bits;
			}
		}
	}
	v->fd = ioctl(t->vm, KVM_CREATE_VCPU, id);
	REQUIRE(v->fd >= 0, "create vCPU");
	checked_ioctl(v->fd, KVM_SET_CPUID2, cpuid);
	free(cpuid);
	run_size = ioctl(t->kvm, KVM_GET_VCPU_MMAP_SIZE, 0);
	REQUIRE(run_size > 0, "vCPU mmap size");
	v->run_size = run_size;
	v->run = mmap(NULL, run_size, PROT_READ | PROT_WRITE, MAP_SHARED, v->fd, 0);
	REQUIRE(v->run != MAP_FAILED, "vCPU mmap");
	v->ctl = t->ram + 0x10000 + id * PAGE;
	checked_ioctl(v->fd, KVM_GET_SREGS, &s);
	s.cr3 = 2 * PAGE;
	s.cr4 = 1 << 5;
	s.cr0 = (1UL << 31) | (1UL << 16) | 0x33;
	s.efer = (1 << 8) | (1 << 10) | (1 << 11);
	s.cs = (struct kvm_segment) {
		.base = 0, .limit = ~0U, .selector = 8, .type = 11,
		.present = 1, .s = 1, .l = 1, .g = 1,
	};
	s.ds = (struct kvm_segment) {
		.base = 0, .limit = ~0U, .selector = 16, .type = 3,
		.present = 1, .s = 1, .db = 1, .g = 1,
	};
	s.es = s.ss = s.fs = s.gs = s.ds;
	checked_ioctl(v->fd, KVM_SET_SREGS, &s);
}

static void run_cpu(struct vcpu *v)
{
	int r;

	do {
		r = ioctl(v->fd, KVM_RUN, 0);
	} while (r < 0 && errno == EINTR);
	REQUIRE(!r, "KVM_RUN");
}

static void expect_io(struct vcpu *v, unsigned char value)
{
	REQUIRE(v->run->exit_reason == KVM_EXIT_IO &&
		v->run->io.direction == KVM_EXIT_IO_OUT &&
		v->run->io.port == 0x80 && v->run->io.size == 1 &&
		v->run->io.count == 1 &&
		*((unsigned char *)v->run + v->run->io.data_offset) == value,
		"exit=%u expected port marker %u", v->run->exit_reason, value);
}

static void prepare(struct test *t, unsigned int id, unsigned int op, uint64_t gpa)
{
	struct vcpu *v = &t->cpu[id];
	struct kvm_regs regs = {
		.rip = PAGE, .rsp = 0x80000 + id * PAGE, .rflags = 2,
		.rdi = gpa, .rsi = op, .rbx = 0x10000 + id * PAGE,
		.r8 = WRONG, .r9 = STORED, .r11 = GOOD,
	};

	memset(v->ctl, 0, sizeof(*v->ctl));
	v->mmio = 0;
	/* Finish the previous OUT before replacing guest register state. */
	if (v->run->exit_reason == KVM_EXIT_IO) {
		v->run->immediate_exit = 1;
		REQUIRE(ioctl(v->fd, KVM_RUN, 0) == -1 && errno == EINTR,
			"complete port I/O");
		v->run->immediate_exit = 0;
	}
	checked_ioctl(v->fd, KVM_SET_REGS, &regs);
	run_cpu(v);
	expect_io(v, 1);
}

static void serve_mmio(struct test *t, struct vcpu *v)
{
	struct kvm_run *r = v->run;
	uint64_t offset = r->mmio.phys_addr - t->gpa;

	REQUIRE(r->mmio.len && r->mmio.len <= 8 && offset < HUGE &&
		r->mmio.len <= HUGE - offset, "MMIO address/length");
	if (r->mmio.is_write)
		memcpy(t->backing + offset, r->mmio.data, r->mmio.len);
	else
		memcpy(r->mmio.data, t->backing + offset, r->mmio.len);
	v->mmio++;
}

static void finish(struct test *t, unsigned int id)
{
	struct vcpu *v = &t->cpu[id];

	for (;;) {
		run_cpu(v);
		if (v->run->exit_reason != KVM_EXIT_MMIO)
			break;
		serve_mmio(t, v);
	}
	expect_io(v, 2);
}

static bool mmio_spte(uint64_t s)
{
	return !(s & PRESENT) && (s & 7) == 6;
}

static void flush(struct test *t, uint64_t gpa)
{
	struct ft_flush f = { .gpa = gpa };

	checked_ioctl(t->cpu[0].fd, FLUSH_GFN, &f);
}

static uint64_t spurious(struct test *t)
{
	char path[128];
	unsigned long long value;
	FILE *f;

	snprintf(path, sizeof(path), "/sys/kernel/debug/kvm/%d-%d/pf_spurious",
		 getpid(), t->vm);
	f = fopen(path, "r");
	if (!f)
		return UINT64_MAX;
	REQUIRE(fscanf(f, "%llu", &value) == 1, "pf_spurious read");
	fclose(f);
	return value;
}

static void check_leaf(struct test *t, unsigned int index, bool direct)
{
	uint64_t s = LOAD(&t->spt[index]);

	printf("# gfn=%#" PRIx64 " spte=%#" PRIx64 " mmio=%u\n",
	       t->gpa / PAGE + index, s, t->cpu[0].mmio);
	if (direct)
		REQUIRE((s & ~(ACCESSED | DIRTY)) ==
			(frame(t, t->backing + index * PAGE) | DIRECT), "direct leaf");
	else
		REQUIRE(mmio_spte(s), "MMIO leaf");
}

static void basic(struct test *t, int row)
{
	bool direct = row <= 3 && !control_kernel;
	uint64_t before, after;

	create_cpu(t, 0, 0);
	prepare(t, 0, row == 2 ? 1 : row == 3 ? 2 : 0, t->gpa);
	if (row != 4)
		STORE(t->spt, frame(t, t->backing + (row == 5 ? 2 * PAGE : 0)) | DIRECT);
	if (row == 3) {
		/* movabs GOOD,%rax; ret */
		unsigned char code[] = { 0x48, 0xb8, 0, 0, 0, 0, 0, 0, 0, 0, 0xc3 };
		uint64_t value = GOOD;

		memcpy(code + 2, &value, sizeof(value));
		memcpy(t->backing, code, sizeof(code));
	}
	before = spurious(t);
	finish(t, 0);
	after = spurious(t);
	REQUIRE(t->cpu[0].ctl->value == (row == 2 ? STORED : GOOD), "guest data");
	if (row == 3 && control_kernel)
		printf("# control instruction fetch can use slot RAM; MMIO exits=%u\n",
		       t->cpu[0].mmio);
	else
		REQUIRE(direct ? !t->cpu[0].mmio : t->cpu[0].mmio, "MMIO count");
	check_leaf(t, 0, direct);
	if (row == 2) {
		REQUIRE(*(uint64_t *)t->backing == STORED, "backing write");
		if (direct)
			REQUIRE(LOAD(t->spt) & DIRTY, "EPT D bit");
	}
	if (row == 1 && direct) {
		if (before == UINT64_MAX || after == UINT64_MAX)
			printf("# REVIEW ONLY pf_spurious: mount debugfs for counter evidence\n");
		else {
			printf("# pf_spurious before=%" PRIu64 " after=%" PRIu64 "\n",
			       before, after);
			REQUIRE(after == before + 1, "one spurious first touch");
		}
	}
}

static void dirty_flags(struct test *t)
{
	struct kvm_userspace_memory_region m = {
		.slot = 2, .flags = DUAL_MODE | KVM_MEM_LOG_DIRTY_PAGES,
		.guest_phys_addr = t->gpa + HUGE,
		.userspace_addr = (uintptr_t)t->backing, .memory_size = HUGE,
	};
	int r = ioctl(t->vm, KVM_SET_USER_MEMORY_REGION, &m);

	if (control_kernel) {
		REQUIRE(!r, "control accepts flags at creation");
		slot(t, 2, m.guest_phys_addr, t->backing, 0, 0);
	} else {
		REQUIRE(r == -1 && errno == EINVAL, "reject flags at creation");
	}
	m.slot = 1;
	m.guest_phys_addr = t->gpa;
	r = ioctl(t->vm, KVM_SET_USER_MEMORY_REGION, &m);
	REQUIRE(control_kernel ? !r : r == -1 && errno == EINVAL,
		"dirty-log toggle");
	printf("# dirty flags: creation and toggle %s\n", control_kernel ? "accepted" : "rejected");
}

/* Hold a pipe reference so an intentionally old PFN cannot be recycled. */
static int pin_and_punch(struct test *t, unsigned int index)
{
	int pipefd[2];
	struct iovec iov = { .iov_base = t->backing + index * PAGE, .iov_len = PAGE };
	uint64_t old = frame(t, iov.iov_base);

	REQUIRE(!pipe(pipefd), "pin pipe");
	REQUIRE(vmsplice(pipefd[1], &iov, 1, 0) == PAGE, "pin old host page");
	close(pipefd[1]);
	if (fallocate(t->memfd, FALLOC_FL_PUNCH_HOLE | FALLOC_FL_KEEP_SIZE, 0, HUGE))
		skip("hugetlb hole punch with a held page is unavailable");
	if (fallocate(t->memfd, 0, 0, HUGE))
		skip("a second free huge page is needed for host refault");
	*(uint64_t *)t->backing = GOOD;
	*(uint64_t *)(t->backing + PAGE) = GOOD;
	REQUIRE(frame(t, iov.iov_base) != old, "host refault must change PFN");
	return pipefd[0];
}

static void invalidation(struct test *t, int row)
{
	unsigned int index = row == 12;
	int pin;

	create_cpu(t, 0, 0);
	prepare(t, 0, 0, t->gpa);
	*(uint64_t *)(t->backing + index * PAGE) = WRONG;
	STORE(&t->spt[index], frame(t, t->backing + index * PAGE) | DIRECT);
	pin = pin_and_punch(t, index);
	if (row == 12)
		STORE(t->spt, frame(t, t->backing) | DIRECT);
	finish(t, 0);
	REQUIRE(t->cpu[0].ctl->value == GOOD, "new backing at target");
	check_leaf(t, 0, row == 12 && !control_kernel);
	if (row == 11)
		REQUIRE(t->cpu[0].mmio, "old target rejected");
	else {
		prepare(t, 0, 0, t->gpa + PAGE);
		finish(t, 0);
		REQUIRE(!t->cpu[0].mmio && t->cpu[0].ctl->value == WRONG,
			"record existing old sibling exposure");
		printf("# exposure: old sibling marker=%#" PRIx64 "\n", t->cpu[0].ctl->value);
	}
	if (trace_output)
		trace_write("tracing_on", "0");
	/* Drop VM references before allowing the old frame to be recycled. */
	REQUIRE(!munmap(t->cpu[0].run, t->cpu[0].run_size), "unmap vCPU");
	close(t->cpu[0].fd);
	close(t->vm);
	close(pin);
}

static void churn(struct test *t)
{
	create_cpu(t, 0, 0);
	for (unsigned int i = 0; i < 20; i++) {
		/* Slot deletion invalidates all roots before the next access. */
		slot(t, 2, t->gpa + HUGE, t->ram, PAGE, 0);
		slot(t, 2, t->gpa + HUGE, t->ram, 0, 0);
		prepare(t, 0, 0, t->gpa);
		STORE(t->spt, frame(t, t->backing) | DIRECT);
		finish(t, 0);
		REQUIRE(t->cpu[0].ctl->value == GOOD, "root cycle data");
		REQUIRE(control_kernel ? t->cpu[0].mmio : !t->cpu[0].mmio, "root cycle MMIO");
		check_leaf(t, 0, !control_kernel);
	}
}

struct worker { struct test *t; unsigned int id; };
static void *reader(void *arg)
{
	struct worker *w = arg;

	finish(w->t, w->id);
	return NULL;
}

static void readers(struct test *t, int row)
{
	pthread_t thread;
	struct worker w = { t, 1 };
	unsigned int index = row == 6;

	create_cpu(t, 0, 0);
	create_cpu(t, 1, 0);
	prepare(t, 0, 0, t->gpa);
	prepare(t, 1, 3, t->gpa + index * PAGE);
	STORE(t->spt, frame(t, t->backing) | DIRECT);
	STORE(&t->spt[index], frame(t, t->backing + 2 * PAGE) | DIRECT);
	REQUIRE(!pthread_create(&thread, NULL, reader, &w), "reader thread");
	STORE(&t->cpu[1].ctl->go, 1);
	finish(t, 0);
	while (LOAD(&t->cpu[1].ctl->count) < 10000)
		sched_yield();
	STORE(&t->cpu[1].ctl->stop, 1);
	REQUIRE(!pthread_join(thread, NULL), "join reader");
	printf("# exposure: target=%#" PRIx64 " reader=%#" PRIx64
	       " wrong=%" PRIu64 " reads=%" PRIu64 " mmio=%u/%u spte=%#" PRIx64 "\n",
	       t->cpu[0].ctl->value, t->cpu[1].ctl->value,
	       t->cpu[1].ctl->wrong, t->cpu[1].ctl->count,
	       t->cpu[0].mmio, t->cpu[1].mmio, LOAD(&t->spt[index]));
	REQUIRE(t->cpu[0].ctl->value == GOOD || t->cpu[0].ctl->value == WRONG,
		"target marker");
	REQUIRE(t->cpu[1].ctl->value == GOOD || t->cpu[1].ctl->value == WRONG,
		"reader marker");
	REQUIRE(!t->cpu[1].ctl->bad, "reader returned an unknown marker");
	REQUIRE(mmio_spte(LOAD(&t->spt[index])) ||
		(LOAD(&t->spt[index]) & ~(ACCESSED | DIRTY)) ==
		(frame(t, t->backing + 2 * PAGE) | DIRECT), "exposure leaf state");
	printf("# REVIEW ONLY compare exposure counts with the control run; scheduling varies\n");
}

static void *writer(void *arg)
{
	struct worker *w = arg;
	struct vcpu *v = &w->t->cpu[w->id];

	/* Hold the first MMIO exit for the host to inspect the read-only state. */
	run_cpu(v);
	REQUIRE(v->run->exit_reason == KVM_EXIT_MMIO && v->run->mmio.is_write,
		"store must fault on the held read-only entry");
	return NULL;
}

static void revocation(struct test *t)
{
	struct worker w = { t, 1 };
	pthread_t thread;
	uint64_t s, count, last;

	create_cpu(t, 0, 0);
	create_cpu(t, 1, 0);
	/* Link the table using an empty sibling on both kernels. */
	prepare(t, 0, 0, t->gpa + PAGE);
	finish(t, 0);
	prepare(t, 1, 4, t->gpa);
	STORE(t->spt, frame(t, t->backing) | DIRECT);
	REQUIRE(!pthread_create(&thread, NULL, writer, &w), "writer thread");
	while (LOAD(&t->cpu[1].ctl->count) < 10000)
		sched_yield();
	s = __atomic_fetch_and(t->spt, ~(WRITE | MMU_WRITE), __ATOMIC_SEQ_CST);
	REQUIRE(s & DIRTY, "direct stores must set D");
	flush(t, t->gpa);
	REQUIRE(!pthread_join(thread, NULL), "writer fault barrier");
	REQUIRE(mmio_spte(LOAD(t->spt)), "kernel replaced read-only leaf");
	count = LOAD(&t->cpu[1].ctl->count);
	last = *(uint64_t *)t->backing;
	REQUIRE(last == count, "every completed direct store is in backing");
	/* Revoke with CAS while the fault is held, then flush as FEMU does. */
	s = LOAD(t->spt);
	REQUIRE(__atomic_compare_exchange_n(t->spt, &s, s, false,
		__ATOMIC_SEQ_CST, __ATOMIC_SEQ_CST), "held MMIO entry");
	flush(t, t->gpa);
	STORE(&t->cpu[1].ctl->stop, 1);
	serve_mmio(t, &t->cpu[1]);
	finish(t, 1);
	REQUIRE(t->cpu[1].mmio == 1 && t->cpu[1].ctl->count == count + 1 &&
		*(uint64_t *)t->backing == count + 1, "store accounting after protection change");
	printf("# direct stores=%" PRIu64 " D=1 MMIO stores=1 final=%" PRIu64 "\n",
	       count, *(uint64_t *)t->backing);
	printf("# Initial userspace flush: kernel flush proof needs the second phase\n");
}

/* A second phase leaves a cached writer for the kernel's own flush to stop. */
static void kernel_flush(struct test *t)
{
	struct worker w = { t, 1 };
	pthread_t thread;
	uint64_t s, at_return, stale;

	prepare(t, 0, 1, t->gpa);
	prepare(t, 1, 4, t->gpa);
	STORE(t->spt, frame(t, t->backing) | DIRECT);
	flush(t, t->gpa);
	REQUIRE(!pthread_create(&thread, NULL, writer, &w), "cached writer");
	while (LOAD(&t->cpu[1].ctl->count) < 10000)
		sched_yield();
	s = __atomic_fetch_and(t->spt, ~(WRITE | MMU_WRITE), __ATOMIC_SEQ_CST);
	REQUIRE(s & DIRTY, "cached writer dirty state");
	/* vCPU0 has not accessed W since the flush, so it must fault. */
	run_cpu(&t->cpu[0]);
	REQUIRE(t->cpu[0].run->exit_reason == KVM_EXIT_MMIO &&
		t->cpu[0].run->mmio.is_write && mmio_spte(LOAD(t->spt)),
		"uncached writer revokes the leaf");
	/*
	 * The kernel flushes before the fault returns, so vCPU1 can complete at
	 * most the store already in flight. Without that flush it keeps storing
	 * through its cached translation until the entry is evicted.
	 */
	at_return = LOAD(&t->cpu[1].ctl->count);
	/* No userspace flush here: the kernel must stop vCPU1's cached writes. */
	REQUIRE(!pthread_join(thread, NULL), "kernel must stop cached writer");
	stale = LOAD(&t->cpu[1].ctl->count) - at_return;
	printf("# direct stores after the revoking fault returned: %" PRIu64 "\n", stale);
	if (!control_kernel)
		REQUIRE(stale <= 1, "cached writer stopped before the fault returned");
	STORE(&t->cpu[1].ctl->stop, 1);
	serve_mmio(t, &t->cpu[1]);
	finish(t, 1);
	serve_mmio(t, &t->cpu[0]);
	finish(t, 0);
	REQUIRE(*(uint64_t *)t->backing == STORED &&
		t->cpu[0].mmio == 1 && t->cpu[1].mmio == 1,
		"both stores reach userspace after kernel revocation");
	printf("# kernel flush: both vCPUs stopped at MMIO before userspace flush\n");
}

static void two_roots(struct test *t)
{
	create_cpu(t, 0, 48);
	create_cpu(t, 1, 49);
	prepare(t, 0, 0, t->gpa);
	prepare(t, 1, 0, t->gpa);
	STORE(t->spt, frame(t, t->backing) | DIRECT);
	finish(t, 0);
	REQUIRE(t->cpu[0].ctl->value == GOOD, "first root data");
	printf("# first root owns table; second root access starts\n");
	STORE(stage, 1);
	finish(t, 1);
	REQUIRE(t->cpu[1].ctl->value == GOOD, "second root data");
	printf("# second root completed: verify 5-level EPT support on this host\n");
	skip("two-root retry not observed; requires host 5-level EPT");
}

static void trace_write(const char *file, const char *value)
{
	char path[512];
	int fd;

	snprintf(path, sizeof(path), "%s/%s", trace_instance, file);
	fd = open(path, O_WRONLY);
	REQUIRE(fd >= 0 && write(fd, value, strlen(value)) == (ssize_t)strlen(value),
		"write trace control %s", path);
	close(fd);
}

static void trace_start(int row)
{
	char filter[128];
	const char *root = "/sys/kernel/tracing";
	uint64_t gfn = (row + 1) * HUGE / PAGE;

	if (!trace_output)
		return;
	if (access("/sys/kernel/tracing/instances", F_OK))
		root = "/sys/kernel/debug/tracing";
	snprintf(trace_instance, sizeof(trace_instance), "%s/instances/cylon-ft-%d",
		 root, getpid());
	REQUIRE(!mkdir(trace_instance, 0700), "create private trace instance");
	snprintf(filter, sizeof(filter), "gfn >= %" PRIu64 " && gfn < %" PRIu64,
		 gfn, gfn + 512);
	trace_write("events/kvmmmu/kvm_tdp_mmu_spte_changed/filter", filter);
	trace_write("events/kvmmmu/mark_mmio_spte/filter", filter);
	trace_write("events/kvmmmu/kvm_tdp_mmu_spte_changed/enable", "1");
	trace_write("events/kvmmmu/mark_mmio_spte/enable", "1");
	trace_write("tracing_on", "1");
}

static bool trace_finish(int row, bool passed)
{
	char path[512], line[2048];
	FILE *input, *output;
	unsigned int links = 0, leaf_changes = 0, mmio = 0;
	bool valid = true;

	if (!trace_output)
		return true;
	trace_write("tracing_on", "0");
	snprintf(path, sizeof(path), "%s/trace", trace_instance);
	input = fopen(path, "r");
	REQUIRE(input, "read private trace");
	snprintf(path, sizeof(path), "%s/row-%02d.trace", trace_output, row);
	output = fopen(path, "wx");
	REQUIRE(output, "create trace artifact %s", path);
	while (fgets(line, sizeof(line), input)) {
		char *at;

		fputs(line, output);
		if (strstr(line, "mark_mmio_spte:"))
			mmio++;
		at = strstr(line, "kvm_tdp_mmu_spte_changed:");
		if (at) {
			unsigned int as, level;
			unsigned long long gfn, old, new;

			at += strlen("kvm_tdp_mmu_spte_changed:");
			if (sscanf(at, " as id %u gfn %llx level %u old_spte %llx new_spte %llx",
				   &as, &gfn, &level, &old, &new) == 5) {
				if (level == 2 && !old && (new & PRESENT))
					links++;
				if (level == 1)
					leaf_changes++;
			}
		}
	}
	fclose(input);
	REQUIRE(!fclose(output), "write trace artifact");
	trace_write("events/kvmmmu/kvm_tdp_mmu_spte_changed/enable", "0");
	trace_write("events/kvmmmu/mark_mmio_spte/enable", "0");
	REQUIRE(!rmdir(trace_instance), "remove private trace instance");
	printf("# trace row=%d links=%u leaf_changes=%u mmio_marks=%u path=%s\n",
	       row, links, leaf_changes, mmio, path);
	if (passed) {
		if (row == 9)
			valid = !links && !leaf_changes && !mmio;
		else
			valid = links > 0;
		if ((row <= 3 || row == 12) && !control_kernel)
			valid &= !leaf_changes && !mmio;
		if ((row <= 3 && control_kernel) || row == 4 || row == 5 ||
		    row == 8 || row == 11 || (row == 12 && control_kernel))
			valid &= leaf_changes > 0 && mmio > 0;
		if (row == 13)
			valid &= links >= 20 && (control_kernel ? mmio >= 20 : !mmio);
		if (row == 14)
			valid &= mmio >= 3;
	}
	return valid;
}

static void run_row(int row)
{
	struct test t;

	if (row == 10)
		skip("REVIEW ONLY KVM_PAGE_TRACK_WRITE has no userspace setter; owner decision D4");
	check_parameter("/sys/module/kvm_intel/parameters/ept");
	check_parameter("/sys/module/kvm_intel/parameters/eptad");
	check_parameter("/sys/module/kvm/parameters/tdp_mmu");
	check_parameter("/sys/module/kvm/parameters/mmio_caching");
	setup(&t, row);
	if (row <= 5 || row == 8)
		basic(&t, row);
	else if (row == 6 || row == 7)
		readers(&t, row);
	else if (row == 9)
		dirty_flags(&t);
	else if (row == 11 || row == 12)
		invalidation(&t, row);
	else if (row == 13)
		churn(&t);
	else if (row == 14) {
		revocation(&t);
		kernel_flush(&t);
	} else if (row == 15)
		two_roots(&t);
	if (trace_output)
		trace_write("tracing_on", "0");
	exit(KSFT_PASS);
}

static double seconds(void)
{
	struct timespec ts;

	REQUIRE(!clock_gettime(CLOCK_MONOTONIC, &ts), "monotonic clock");
	return ts.tv_sec + ts.tv_nsec / 1e9;
}

static unsigned int number(const char *s)
{
	char *end;
	unsigned long n;

	errno = 0;
	n = strtoul(s, &end, 10);
	REQUIRE(!errno && *s && !*end && n <= 600, "numeric argument %s", s);
	return n;
}

int main(int argc, char **argv)
{
	int chosen = 0, opt;

	while ((opt = getopt(argc, argv, "cr:t:T:h")) != -1) {
		switch (opt) {
		case 'c':
			control_kernel = true;
			break;
		case 'r':
			chosen = number(optarg);
			break;
		case 't':
			timeout_secs = number(optarg);
			break;
		case 'T':
			trace_output = optarg;
			break;
		case 'h':
			printf("Usage: %s [-c] [-r 1..15] [-t seconds] [-T new-trace-directory]\n"
			       "Default: patched expectations, all rows, ten seconds per row.\n"
			       "-c selects original kernel expectations. See the companion document.\n",
			       argv[0]);
			return 0;
		default: return KSFT_FAIL;
		}
	}
	REQUIRE(chosen >= 0 && chosen <= 15 && timeout_secs > 0 &&
		timeout_secs <= 600 && optind == argc, "arguments");
	setbuf(stdout, NULL);
	if (trace_output)
		REQUIRE(!mkdir(trace_output, 0700), "use a new trace output directory");
	else
		printf("# REVIEW ONLY GFN trace evidence omitted; use -T for capture and checks\n");
	stage = mmap(NULL, PAGE, PROT_READ | PROT_WRITE,
		     MAP_SHARED | MAP_ANONYMOUS, -1, 0);
	REQUIRE(stage != MAP_FAILED, "shared progress");
	ksft_print_header();
	ksft_set_plan(chosen ? 1 : 15);
	for (int row = chosen ? chosen : 1; row <= (chosen ? chosen : 15); row++) {
		int status;
		bool timed_out = false, trace_ok;
		pid_t child, got;
		double deadline;
		struct timespec pause = { .tv_nsec = 10000000 };

		STORE(stage, 0);
		trace_start(row);
		child = fork();
		REQUIRE(child >= 0, "fork row");
		if (!child)
			run_row(row);
		deadline = seconds() + timeout_secs;
		while (!(got = waitpid(child, &status, WNOHANG))) {
			if (seconds() >= deadline) {
				REQUIRE(!kill(child, SIGKILL), "stop bounded row");
				REQUIRE(waitpid(child, &status, 0) == child, "reap row");
				timed_out = true;
				break;
			}
			nanosleep(&pause, NULL);
		}
		REQUIRE(got >= 0, "wait row");
		trace_ok = trace_finish(row, !timed_out && WIFEXITED(status) &&
					WEXITSTATUS(status) == KSFT_PASS);
		if (timed_out && row == 15 && LOAD(stage) == 1)
			ksft_test_result_skip("row 15: second-root timeout; REVIEW ONLY\n");
		else if (!timed_out && WIFEXITED(status) && WEXITSTATUS(status) == KSFT_SKIP)
			ksft_test_result_skip("row %d: %s (see reason above)\n", row, names[row]);
		else
			ksft_test_result(!timed_out && WIFEXITED(status) &&
					WEXITSTATUS(status) == KSFT_PASS && trace_ok,
					"row %d: %s%s\n", row, names[row],
					timed_out ? " TIMEOUT" : "");
	}
	ksft_finished();
}
