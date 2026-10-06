# Dual-mode first-touch test

Build from `tools/testing/selftests/kvm` with `make OUTPUT=/absolute/output`.
This checkout lacks the common KVM test Makefile, so the added Makefile builds
only this test. It uses the local kselftest result API and a small long-mode
guest, without the common KVM library. Use `KHDR_INCLUDES=-isystem\ /path/to/usr/include`
to select exported kernel headers.

Run as root inside the disposable nested test machine, with Cylon KVM loaded,
EPT, EPT A/D, TDP MMU and MMIO caching enabled. Reserve at least two free 2 MiB
huge pages and mount debugfs and tracefs. PFN visibility needs CAP_SYS_ADMIN.
All ordinary guest memory is in slot 0; slot 1 is a 2 MiB-aligned hugetlb memfd.
The test maps the slot's single linear SPT page through KVM_GET_LINEAR_SPT and
constructs leaves with FEMU's EPT and software bits, initially A/D clear.
Each row creates a fresh VM and has its own GPA region. The parent bounds each
row, including KVM_RUN and thread joins, and kills a child that exceeds its
budget. Missing prerequisites produce TAP skips; an assertion or unexpected
timeout fails the process. No test silently counts a missing prerequisite as
runtime evidence.

Examples (execute only on the test machine):

```
./x86_64/dual_mode_first_touch_test -T /tmp/ft-traces
./x86_64/dual_mode_first_touch_test -c -T /tmp/control-traces
./x86_64/dual_mode_first_touch_test -r 14 -t 20 -T /tmp/revoke-traces
```

`-c` selects the original kernel's expectations for rows 1–3, 9, 12, 13 and 14.
`-r` selects one row (1 to 16); `-t` sets its timeout in seconds (default 10).
`-T` requires a new output directory. It uses a private tracefs instance and
saves GFN-filtered SPTE changes and MMIO marks for each row. It checks parent
links, the expected leaf-change/MMIO-mark presence for direct and rejected
accesses, 20 links for root churn, and MMIO marks for revocation. Concurrent
exposure traces still need review alongside the printed data and SPTEs. Without `-T`, trace
evidence is explicitly marked review-only. Row 1 checks pf_spurious increases
by one if its VM's debugfs counter is readable; otherwise that counter is
marked review-only. Run on a quiet machine: another VM using the same GFNs can
add events to the GFN-filtered instance.

| Row | Check and interpretation |
| --- | --- |
| 1 | Matching read returns the backing marker; direct leaf and zero MMIO on patched kernel, MMIO on control. |
| 2 | Matching write reaches backing; patched leaf remains direct with D set. |
| 3 | Matching executable code returns its marker; patched leaf remains direct without MMIO. Control must replace the leaf with MMIO, but instruction fetch can read slot RAM inside KVM, so an MMIO exit is recorded rather than required. |
| 4 | Empty target returns backing data through userspace MMIO and ends with an MMIO SPTE. |
| 5 | Another page's PFN is rejected; returned data is from the correct backing, final SPTE is MMIO. Cached revocation is exercised separately in row 14. |
| 6 | Concurrent target and sibling reader; record wrong-marker count, every reader value, exit counts and final leaf. Which vCPU attaches first is deliberately unscheduled. Exposure comparison is review-only. |
| 7 | Concurrent readers of the wrong target; record whether wrong data was visible during attachment. The race need not occur on every run. Exposure comparison is review-only. |
| 8 | PROT_READ host mapping, writable EPT leaf, guest read: reject the leaf and return backing data through MMIO. |
| 9 | Reject dual-mode plus dirty logging at creation and on a flags-only change with EINVAL. Control accepts both. Owner decision D2 replaces the proposal's dirty sibling experiment. |
| 10 | SKIP, review-only by owner decision D4: KVM_PAGE_TRACK_WRITE requires an in-kernel client. No test-only kernel ABI is added. |
| 11 | Punch the detached backing, refault to a different PFN and reject the old target. |
| 12 | Refault the backing and rewrite only the target; a sibling still returns the old marker, recording the existing exposure. |
| 13 | Delete an unused slot, rewrite the direct leaf, and access it, for 20 root-invalidation cycles. |
| 14 | Hold a writer at its MMIO exit after clearing W and MMU-writable and flushing. Check prior stores, D, and the final userspace store. A second phase omits the userspace flush after clearing W: an uncached vCPU faults and the kernel must force the cached writer to MMIO too. On the patched kernel the cached writer may complete at most one direct store after that fault returns; without the flush it keeps storing until the entry is evicted. |
| 15 | Keep a 48-bit vCPU root alive while a 49-bit vCPU accesses the table. A timeout specifically after the second access starts is a recorded known progress defect, reported as SKIP/review-only, never PASS. Unsupported MAXPHYADDR or completion without the defect is also SKIP. Confirm 5-level EPT on the host when assessing this row. |
| 16 | Version 2 only (skips without it). The guest stack is on a slot page whose leaf holds KVM_CYLON_SPTE_EMULATE; the guest runs int3. The #BP push must exit with KVM_CYLON_FAULT_DELIVERY (EPT violation, write), then, with KVM's MMIO SPTE in place, again with ACCESS and DELIVERY only (EPT misconfiguration during delivery; before this fix KVM_INTERNAL_ERROR_DELIVERY_EV). After userspace installs a direct leaf, the event is delivered: the handler sees the pushed return RIP, which is also in the slot backing. The trace must show an MMIO mark. |

Rows 11–12 hold a pipe reference obtained with vmsplice to the old huge page
before punching it. Thus a deliberately old leaf cannot point at memory freed
for an unrelated allocation. They skip if the host cannot punch/refill this
backing. The old reference is released only after the VM and vCPU mappings
are closed. This experiment intentionally violates the production stable
backing restriction; it does not make that restriction unnecessary.

Row 14's first phase follows the proposal, whose explicit flush means that
phase alone cannot prove the new kernel flush. The second phase adds that
check. On the original kernel it may time out if the cached writer retains
its translation; this is an expected negative result to preserve in the
control report, and the test process returns failure. A natural TLB eviction
can make control complete, so one successful control run is inconclusive.
The MMIO entry is already installed by KVM when the first phase's barrier is
reached; its userspace CAS confirms that exact entry and the flush completes
the userspace revocation sequence. Dirty state comes from the sampled EPT D
bit and explicit userspace write accounting, not a dirty log on the dual slot.

The exposure rows produce observations, not a proof that patched behavior is
no worse under all schedules. Compare multiple control and patched runs and
review their traces. Write-tracking review must confirm that the nonpresent
fault path skips page_fault_handle_page_track(), that the new predicate calls
kvm_slot_page_track_is_active(..., KVM_PAGE_TRACK_WRITE), and that a rejected
leaf reaches the MMIO path with its flush. Sibling publication, detached-table
tracking, concurrent userspace stores, and two-root progress remain outside
this fix.

The proposal's control expectation for execution needs this correction:
kvm_fetch_guest_virt() reads the slot's host backing directly. An MMIO SPTE
does not itself require a userspace MMIO exit for instruction fetch. The test
therefore requires the control SPTE/trace evidence, while still requiring the
patched execution to complete directly with the correct return value.

No FEMU workload, KASAN run, module load, or VM boot is part of the build.
