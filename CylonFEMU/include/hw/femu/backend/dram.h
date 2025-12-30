#ifndef __FEMU_MEM_BACKEND
#define __FEMU_MEM_BACKEND

#include <stdint.h>
#include <numa.h>

#include "hw/femu/femu.h"

typedef struct FemuCtrl FemuCtrl;

/* DRAM backend SSD address space */
typedef struct SsdDramBackend {
    void    *logical_space; //NAND
    void    *buf_space;
    
    uint64_t size; /* in bytes */
    uint64_t buf_size;

    uint64_t base_gpa;
    int     femu_mode;
} SsdDramBackend;

int init_dram_backend(FemuCtrl *);
void free_dram_backend(SsdDramBackend *);

int backend_rw(SsdDramBackend *, QEMUSGList *, uint64_t *, bool);

#endif
