#ifndef __FEMU_FTL_BUFFER_H
#define __FEMU_FTL_BUFFER_H

#include "../nvme.h"
// #include "ftl.h"
typedef uint64_t lpn_t;
struct ssd;

int flush_pg(struct ssd* ssd, lpn_t lpn);

extern bool ioctl_flag;


struct buffer;
struct set;


struct buffer_entry {
	lpn_t lpn;
    // uint32_t idx;
    bool dirty;
    union {
        /*struct for CLOCK*/
        struct {
            uint8_t ref; 
        };
        /*struct for S3-FIFO*/
        struct {
            uint8_t freq;
            uint8_t tier; /* 0 = S, 1 = M */
        };
    };
    
	QTAILQ_ENTRY(buffer_entry) b_entry;
};

struct buffer_ops {
    int (*evict_victim)(struct buffer *, struct set *);
    int (*insert_entry)(struct buffer *, struct buffer_entry *);
};

struct set {  
    union {
        QTAILQ_HEAD(queue, buffer_entry) queue;
        struct buffer_entry* entry; /* For Direct-mapped buffer */
    };

    union {
        /* tmp for LIFO */
        struct {
            QTAILQ_HEAD(, buffer_entry) tmp;
        };

        /* for S3-FIFO */
        struct {
            QTAILQ_HEAD(, buffer_entry) small;
            QTAILQ_HEAD(, buffer_entry) ghost;

            int cnt_small;
            int cnt_main;
            int cnt_ghost;
        };
    };
    
    struct buffer_entry *hand;   // clock hand; NULL if empty
    int cnt;
};

enum {
    WAY_1,  /* Direct-mapped */
    WAY_2,
    WAY_4,
    WAY_8,
    WAY_16,
    WAY_FULL /* Fully-associate */
};

struct buffer {
    struct ssd *ssd; /* parent */

    uint64_t size; /* # of entries */
    uint64_t entry_cnt;
    double thres_pcent;
    double force_pcent;
    
	GTree *tree;
    GTree *ghost_tree;
    unsigned long *bitmap; /* bitmap for allocation */
    int way;

    uint64_t set_mask;
    struct set* sets;

    /* Eviction policy */
    int policy;
    
    /* Next-N Prefetching */
    int degree;
    /* Prefetch Stride */
    int stride;

    struct buffer_ops ops;

    uint64_t read_hit;
    uint64_t read_miss;
    uint64_t write_hit;
    uint64_t write_miss;

    uint64_t ins_cnt;
    uint64_t evict_cnt;
    
    uint64_t gen;

    SsdDramBackend *ssdbackend;
};


enum {
    INSERT_NO_PREFETCH = 0,
    INSERT_PREFETCH = 1,
};



void direct_mr_add(struct buffer *b, lpn_t lpn);
void direct_mr_del(struct buffer *b, lpn_t lpn);

/* Common OPS */
struct buffer_entry *buffer_entry_init(struct buffer *b, lpn_t lpn);
bool buffer_full(struct buffer *b);
bool buffer_force_eviction(struct buffer *b);
struct buffer_entry* buffer_lookup_entry(struct buffer *b, lpn_t lpn);
struct set* buffer_get_set(struct buffer *b, lpn_t lpn);
// bool buffer_hit(struct buffer *b, lpn_t lpn);

// struct buffer_entry* buffer_select_victim(struct buffer *);
// bool buffer_evict_victim(struct buffer *, struct buffer_entry *);
bool buffer_insert_entry(struct buffer *, struct buffer_entry *, int);
void buffer_clear(struct buffer *);
void buffer_init_set(struct buffer *);
void buffer_destroy_set(struct buffer *);
// void buffer_print_stat(struct buffer *);


/* Todo: refactor for better modularity */
/* LIFO */
int lifo_evict_victim(struct buffer *, struct set *);
int lifo_insert_entry(struct buffer *, struct buffer_entry *);

/* FIFO */
int fifo_evict_victim(struct buffer *, struct set *);
int fifo_insert_entry(struct buffer *, struct buffer_entry *);

/* CLOCK (second chance)*/
int clock_evict_victim(struct buffer *, struct set *);
int clock_insert_entry(struct buffer *, struct buffer_entry *);

/* S3FIFO */
int s3fifo_evict_victim(struct buffer *, struct set *);
int s3fifo_insert_entry(struct buffer *, struct buffer_entry *);

#endif
