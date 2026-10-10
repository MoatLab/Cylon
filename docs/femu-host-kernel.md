# Host kernel for FEMU der=cylon

FEMU's CXL-SSD device (`femu-cxl-ssd`) can map cached pages straight into
the guest with `der=cylon`. This mode needs the CylonLinux kernel of this
repository on the host, with the dual-mode slot fixes. This page tells you
which kernel to build, how to configure the host, and what FEMU asks of the
kernel.

## Which commit to build

Build `CylonLinux/` from the commit that adds this page, or a later one. The
fixes are a series on top of `0cf82e2d2` ("cxlssd: write logs under a log_dir
property, not /home/necsst"):

| Part | Commits (subjects, `KVM: dual-mode slots:` unless noted) |
|---|---|
| Fault exit, version 1 | exit to userspace when emulation fails; drop the synthetic MMIO read, exit on decode only; exit only when the opcode cannot be decoded; map code pages instead of emulating fetches |
| Shared leaves and first touch | keep KVM's own paths off the shared leaves; flush when a fault replaces a present leaf; reject dirty logging; keep a usable leaf on first touch; linearize RIP as the instruction fetch does |
| Fault exit, version 2 | define the version 2 fault exit ABI; hand cold pages to userspace, not the emulator; fail what version 2 cannot serve; hand event delivery faults to userspace; offer fault exit version 2 with EPT and the TDP MMU |
| Tests and documentation | `KVM: selftests:` deliver events through a dual-mode MMIO leaf; `KVM: docs:` describe the Cylon fault exit; `docs:` describe the host kernel for FEMU der=cylon |

The KVM interface is in `CylonLinux/Documentation/virt/kvm/api.rst`, sections
"KVM_EXIT_CYLON_FAULT" and "7.34 KVM_CAP_CYLON_FAULT_EXIT".

## Build configuration

- `CONFIG_X86_64=y`, `CONFIG_KVM=m`, `CONFIG_KVM_INTEL=m`. Set
  `CONFIG_KVM_WERROR=y` to catch new warnings in KVM.
- Use a distinct `CONFIG_LOCALVERSION` (for example `-cylon-kcand`), so you
  can tell this kernel from others with `uname -r`.
- The selftest builds alone: `make -C CylonLinux/tools/testing/selftests/kvm
  OUTPUT=<dir> KHDR_INCLUDES="-isystem <headers>/include"` after
  `make headers_install INSTALL_HDR_PATH=<headers>`. Run it only on a
  disposable test machine (see `dual_mode_first_touch_test.md`).

## Host requirements

| Requirement | How to check |
|---|---|
| Intel CPU with EPT and EPT A/D bits | `/sys/module/kvm_intel/parameters/ept` and `eptad` are `Y` |
| TDP MMU | `/sys/module/kvm/parameters/tdp_mmu` is `Y` (the default) |
| MMIO SPTE caching | `/sys/module/kvm/parameters/mmio_caching` is `Y` |
| Stable backing memory | Shared, preallocated hugetlb backing for the CXL media. No host migration, memory offlining, hole punching or `MADV_DONTNEED` on it while direct mapping is active |

FEMU reads the four parameters and refuses `der=cylon` if one is off. AMD
hosts are not supported: the leaf tables that FEMU writes have the EPT
format.

## VM requirements

- `-machine ...,smm=off`. In SMM a vCPU uses address space 1, which the
  dual-mode slot does not serve. The kernel refuses a dual-mode slot in
  address space 1, and FEMU refuses `der=cylon` with SMM on.
- No nested guest. With version 2, an access by a nested guest to the slot
  makes `KVM_RUN` fail with `-EFAULT`. Version 1 exits only for L1.
- No dirty logging on the slot. The kernel refuses `KVM_MEM_LOG_DIRTY_PAGES`
  together with the dual-mode flag. FEMU revokes its mappings and disables
  Cylon when global dirty logging starts, and refuses dirty-ring logging.
- All vCPUs must use one MMU root role (fixed vCPU models and CPUID). With
  version 2, a fault that links a slot table held by a live root of
  another role (for example another paging depth) fails with `-EFAULT`.
  With version 1, that fault retries for ever (selftest row 15).
- No in-kernel write tracking of the slot's pages (for example a nested
  guest whose EPT tables are on the CXL memory). With version 2, KVM
  fails a write fault on a present leaf of a tracked page with `-EFAULT`
  instead of emulating it; it does not refuse every such access.

## The two versions of the fault exit

Pages that FEMU has not mapped are cold. The capability
`KVM_CAP_CYLON_FAULT_EXIT` selects what KVM does on an access to a cold page.

| Mode | KVM behaviour on a cold page |
|---|---|
| Capability off | KVM installs an MMIO SPTE and emulates the instruction. An instruction that the emulator does not know (VEX, EVEX, most SSE, `endbr64`) fails in the guest. The older kernel at `0cf82e2d2` instead did a synthetic MMIO read for some of these instructions; this series removes it, so an older FEMU without the capability can now see a guest `#UD` or a KVM internal error there |
| Version 1 (`args[0] = 1`) | KVM emulates data accesses. It exits to FEMU (`KVM_EXIT_CYLON_FAULT`) when the access is to the page of RIP (FETCH) or when it cannot decode the instruction (DECODE). FEMU maps the page and the guest runs the instruction natively |
| Version 2 (`args[0] = 3`) | KVM never installs a present leaf in the slot. Every access to a cold page exits to FEMU with its exact type (read, write, fetch; target or guest page walk). FEMU fills and maps the page. For a data access to a page that the caching API keeps uncached, FEMU writes the marker `0x6a0`, and KVM emulates that page as in version 1. FEMU candidate 3 never marks any other page |

### Event delivery and guest page tables on cold pages

The guest kernel can put page tables, kernel stacks and descriptor tables
on the CXL memory. It does so when the memory is online in a normal zone,
which is what a guest kernel with memory auto-online does by default. The
CPU then touches cold pages while it delivers an interrupt or exception.
KVM refuses an EPT misconfiguration (an MMIO SPTE) during event delivery
with `KVM_INTERNAL_ERROR_DELIVERY_EV`, which ends the VM.

- Version 2: a cold leaf is zero, so the CPU makes an EPT violation, which
  KVM allows during delivery; the exit to FEMU carries
  `KVM_CYLON_FAULT_DELIVERY`. A leaf that FEMU marked `0x6a0` (or its MMIO
  SPTE) exits with the same flag instead of being emulated or ending the
  VM, and so does a guest page walk that an EPT violation reports on it.
  FEMU maps the page and KVM injects the event again. This needs the
  candidate 3 kernel; with an older version 2 kernel only the marked pages
  are exposed, and FEMU marks only pages that the caching API keeps
  uncached.
- Version 1: every cold page is an MMIO SPTE, so the first interrupt that
  touches a cold page table, stack or descriptor table ends the VM. Use
  version 1 only with the CXL memory online as movable memory, which never
  holds them: disable auto-online in the guest (`memhp_default_state=offline`
  on the kernel command line, or no udev rule that onlines memory), then run
  `daxctl online-memory --movable <dax device>` or write `online_movable` to
  each `/sys/devices/system/memory/memoryN/state`. FEMU warns once when it
  activates version 1.

In all modes, KVM keeps a usable leaf: one that FEMU installed (for example
before the table was linked) that maps the page backing the slot, permits
the access, and is writable only if the host mapping is. Without this rule,
the first access to each 2 MiB region replaced a usable leaf with an MMIO
SPTE. Version 2 sends any other leaf to FEMU; the other modes replace it
with an MMIO SPTE and flush the TLBs.

`KVM_CHECK_EXTENSION` returns 2 on an Intel host with EPT, the TDP MMU and
MMIO SPTE caching, and 1 otherwise. Exits report the state at the fault: an
instruction such as `rep movsb` can have done part of its work, and FEMU
runs the vCPU again without rewinding it.

## How FEMU negotiates

1. The first Cylon device of the VM that installs its slot chooses the
   version for the whole VM.
2. With `cylon-emul-exit=on` (the default), FEMU reads the highest version
   with `KVM_CHECK_EXTENSION`.
3. If `cylon-never-emulate` allows it and the kernel reports 2, FEMU enables
   version 2. Otherwise it enables version 1 and warns if you asked for
   version 2.
4. A kernel without the capability gets a warning. Then KVM emulates
   accesses to cold pages; the older Cylon kernel at `0cf82e2d2` also did
   its synthetic MMIO read for some instructions the emulator lacks.

Read the result from QMP with `qom-get` on the device: `der-active`,
`der-emul-exit` (the capability is on) and `der-emul-v2` (version 2 is on).

## FEMU properties

Machine: `-machine q35,cxl=on,smm=off` (with your other machine options).

Device (`-device femu-cxl-ssd,...`):

| Property | Value | Effect |
|---|---|---|
| `der` | `cylon` | Map cached pages through the dual-mode slot |
| `cylon-kernel-ack` | `on` | Required with `der=cylon`; states that the host runs this kernel |
| `cylon-emul-exit` | `on` (default) | Enable the fault exit; `off` keeps stock KVM emulation |
| `cylon-never-emulate` | `auto` (default), `on`, `off` | `auto` and `on` take version 2 when the kernel reports it; `on` warns when it cannot; `off` stays on version 1 |
| `cylon-fault-stop` | `100000` (default) | Watchdog: consecutive exits at one RIP on pages already filled for it that stop the VM; `0` only warns |
| `cylon-revoke-batch` | `64` (default), 1 to 256 | Version 2: the most pages that one full revocation takes |

FEMU before the commit "femu/cxlssd: make the repeated-exit stop a property"
has no `cylon-fault-stop`; its stop bound is fixed at 100,000.

FEMU before the commit "femu/cxlssd: revoke 64 pages per batch by default"
takes `cylon-revoke-batch` from 1 to 64, with 32 as the default.

## Known limits

- KVM still emulates a guest page walk that meets an MMIO SPTE outside
  event delivery. Such a page is one that FEMU marked `0x6a0` (version 2).
  An EPT misconfiguration does not tell a page walk from the access of the
  instruction. The emulator walks the guest page tables in host memory.
- Stage S2 is deferred. The caching API can keep pages uncached: an
  uncached range, or a set whose ways are all pinned. Data accesses to
  these pages stay on KVM's emulator in version 2 too. A code fetch or an
  undecodable instruction on such a page stops the VM. A guest page walk
  or an event delivery on such a page maps it for the instruction (FEMU
  counts it).
- An emulated instruction (version 1, or the version 2 fallback) that also
  touches other pages writes them straight to host memory. FEMU does not
  see these writes.
- Exits are not retired instructions. The version 1 fetch exit and the
  FEMU stop bound (`cylon-fault-stop`) are heuristics. A healthy loop
  that refaults one page at one RIP many times can reach the bound.
- The version 1 fetch exit finds the page of RIP with a guest page walk.
  When RIP is within 15 bytes of its page end, it also walks the next page.
  These walks can set accessed bits in guest page tables, as a code
  prefetch by the CPU can.
- KVM software reads of guest memory (paravirtual structures, the
  emulator for other devices) use the host backing directly. FEMU does
  not see them.
- An emulated locked read-modify-write on a page that FEMU has mapped
  fails, and the guest runs the instruction again on the mapped page. On
  a page that FEMU has not mapped, KVM does the exchange atomically on the
  slot's host address. So the host address of the dual-mode slot must be
  the memory that the direct SPTEs map, as in current FEMU.
- Limits of that rule:
  - On a page that FEMU has not mapped, KVM writes a 16-byte exchange or
    a split-lock exchange through FEMU, which is not atomic. Upstream KVM
    does the same for these exchanges.
  - An access that crosses into a second page does not retry.
  - If FEMU maps the page while KVM does the host exchange, the EPT dirty
    bit stays clear. The data is correct, but FEMU does not charge a
    write-back for that store.
  - FEMU does not see the store of a host exchange. On a page that FEMU
    keeps uncached, FEMU charges the read of the instruction, but no
    program for its write.
