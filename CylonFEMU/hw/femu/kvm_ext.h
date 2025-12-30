#ifndef __FEMU_KVM_EXT_H_
#define __FEMU_KVM_EXT_H_

#include "hw/femu/femu.h"

#include <linux/kvm.h>
#include "sysemu/kvm.h"

#define KVM_MEMSLOT_DUAL_MODE	(1UL << 17)
#define PAGE_SHIFT 12
#define MAX_ORDER 10
#define MAX_CONT_ALLOC_SZ (1<< (MAX_ORDER + PAGE_SHIFT))
// #define BASE_LEAF_SPT_SZ 64

typedef unsigned long long u64;
typedef uint64_t lpn_t;

struct kvm_set_spte_flag {
    uint64_t gpa;
    uint64_t flag;
    lpn_t lpn;
};

struct kvm_memslot_linear_spt {
    u64* spt;
    int npages;
    int offset;
};

struct kvm_memslot_get_linear_spt {
    struct kvm_memslot_linear_spt spt_list[60];
    void *backend_ptr;
    u64 gfn;
    int n;
};

#define KVM_SET_SPTE_FLAG		  _IOW(KVMIO, 0xdd, struct kvm_set_spte_flag)
#define KVM_GET_LINEAR_SPT		  _IOWR(KVMIO, 0xde, struct kvm_memslot_get_linear_spt)

int femu_kvm_spte_set_mmio_flag(uint64_t gfn, uint64_t uaddr);
int femu_kvm_spte_clear_mmio_flag(uint64_t gfn, uint64_t uaddr);

int femu_kvm_set_user_memory_region(FemuCtrl *n);
int femu_kvm_del_user_memory_region(FemuCtrl *n);

int femu_kvm_set_spte_by_cxl_mmio_rate(FemuCtrl *n, int r_cxl);
int femu_kvm_reset_spte_by_cxl_mmio_rate(FemuCtrl *n, int r_cxl);

void femu_kvm_log_init(void);
// FILE *femu_kvm_log_file(void);

void test_spte_modify(void);

void print_spte(uint64_t gpa);


#endif