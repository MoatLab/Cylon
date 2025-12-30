#ifndef __KVM_EXT_FEMU__
#define __KVM_EXT_FEMU__

// #include <linux/kvm_host.h>
#include <linux/kvm_types.h>

struct kvm_memory_slot;

struct kvm_vcpu;
struct kvm_set_spte_flag {
    u64 gpa;
    u64 flag;
    u64 lpn;
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

int kvm_arch_vm_ioctl_set_spte_flag(struct kvm *kvm, struct kvm_set_spte_flag *data);
int kvm_arch_vcpu_ioctl_set_spte_flag(struct kvm_vcpu *kvm_vcpu, struct kvm_set_spte_flag *data);

int kvm_arch_vm_ioctl_get_linear_spt(struct kvm *kvm, struct kvm_memslot_get_linear_spt *data);

int dualslot_create_leaf_spt_cont(struct kvm_memory_slot *slot);
int dualslot_destroy_leaf_spt_cont(struct kvm_memory_slot *slot);
u64 *dualslot_get_leaf_spt(struct kvm_memory_slot *slot, gfn_t gfn);
// int kvm_arch_vcpu_ioctl_get_root_sptep(struct kvm_vcpu *vcpu, struct kvm_get_root_sptep *data)


#endif