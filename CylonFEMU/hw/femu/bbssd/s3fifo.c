#include "buffer.h"


static inline int s3_capS(int ent_max) { int s = ent_max / 10; return s ? s : 1; }
static inline int s3_capM(int ent_max) { int s = s3_capS(ent_max); return ent_max - s; }
static inline int s3_capG(int ent_max) { return s3_capM(ent_max); }

static inline void freq_inc(struct buffer_entry *e) { if (e->freq < 3) e->freq++; }
static inline void freq_dec(struct buffer_entry *e) { if (e->freq > 0) e->freq--; }

static void evict_ghost(struct buffer *b, struct set *set) {
    struct buffer_entry *e = QTAILQ_LAST(&set->ghost);
    if (e) {
        // printf("removed from ghost: 0x%lx\n", e->lpn);
        QTAILQ_REMOVE(&set->ghost, e, b_entry);
        set->cnt_ghost--;
        g_tree_remove(b->ghost_tree, e);
        free(e);
    }
}

static void insert_ghost(struct buffer *b, struct set *set, struct buffer_entry *eptr, int capG) {
    QTAILQ_INSERT_HEAD(&set->ghost, eptr, b_entry);
    set->cnt_ghost++;
    g_tree_insert(b->ghost_tree, eptr, eptr);

    while (set->cnt_ghost > capG) {
        evict_ghost(b, set);
    }
}

static void process_victim(struct buffer *b, struct set* set, struct buffer_entry *victim) {
    // assert(QTAILQ_NEXT(victim, b_entry) == NULL);
    // assert(QTAILQ_PREV(victim, b_entry) == NULL);
    
    /* Flush page to NAND */
    flush_pg(b->ssd, victim->lpn);

    g_tree_remove(b->tree, victim);	//remove from avl tree
    direct_mr_del(b, victim->lpn);

    // free(victim);
    b->entry_cnt--;
    set->cnt--;
}

static void evict_main(struct buffer *b, struct set *set) {
    bool evicted = false;
    struct buffer_entry *victim = NULL;

    while (!evicted) {
        victim = QTAILQ_LAST(&set->queue);
        if (victim) {
            QTAILQ_REMOVE(&set->queue, victim, b_entry);

            if (victim->freq > 0) {
                freq_dec(victim);
                QTAILQ_INSERT_HEAD(&set->queue, victim, b_entry);
                // printf("inserted main->main, lpn: 0x%lx\n", victim->lpn);
            }
            else {
                set->cnt_main--;
                evicted = true;
            }
        }
        else {
            /* Main queue is empty */
            break;
        }
    }

    if (victim != NULL) {
        assert(evicted == true);
        // printf("evicted from main, lpn: 0x%lx\n", victim->lpn);
        process_victim(b, set, victim);
        /* Since the victim is not pushed to ghost, free memory */
        free(victim);
        
    }
}

static void evict_small(struct buffer *b, struct set *set) {
    bool evicted = false;

    struct buffer_entry *victim = NULL;
    int ent_max = (b->way == WAY_FULL) ? b->size : (1 << b->way);
\
    while (!evicted) {
        victim = QTAILQ_LAST(&set->small);
        if (victim) {
            QTAILQ_REMOVE(&set->small, victim, b_entry);

            if (victim->freq > 1) {
                QTAILQ_INSERT_HEAD(&set->queue, victim, b_entry);
                set->cnt_main++;
                
                while (set->cnt_main > s3_capM(ent_max)) {
                    evict_main(b, set);
                }

                /* Since the victim is move to Main queue do not call process_victim */
                victim = NULL;
            }
            else {
                insert_ghost(b, set, victim, s3_capG(ent_max));
                evicted = true;
            }
            set->cnt_small--;
        }
        else {
            /* small queue is empty */
            break;
        }
    }
    
    if (victim != NULL) {
        assert(evicted == true);
        // printf("evicted, small to ghost, lpn: 0x%lx\n", victim->lpn);
        process_victim(b, set, victim);
    }
}

int s3fifo_evict_victim(struct buffer *b, struct set *set)
{
    struct buffer_entry *victim = NULL;
    int ent_max = (b->way == WAY_FULL) ? b->size : (1 << b->way);
    
    if (b->way == WAY_1) {
        victim = set->entry;
        if (victim == NULL)
            return -1;
        process_victim(b, set, victim);
    }
    else {
        /* Evict S */
        if (set->cnt_small > s3_capS(ent_max)) {
            evict_small(b, set);
        }
        else { /* Evict M */
            evict_main(b, set);
        }
    }

    return 1;
}

// static int a = 1;
int s3fifo_insert_entry(struct buffer *b, struct buffer_entry *eptr)
{
    int ent_max = 0;
    struct set* set = buffer_get_set(b, eptr->lpn);

    if(!g_tree_lookup(b->tree, eptr)){

        ent_max = 1 << b->way;
        if (b->way == WAY_FULL) {
            ent_max = b->size;
        }

        // printf("Insert 0x%lx, set idx: 0x%lx, %d/%d %ld/%ld \n", eptr->lpn, eptr->lpn & (b->set_mask), set->cnt, ent_max, b->entry_cnt, b->size);
        // fflush(stdout);
        
        while (!(set->cnt < ent_max)) {
            s3fifo_evict_victim(b, set);
        }
        
        //insert entry
        if (b->way == WAY_1) {
            set->entry = eptr;
        }
        else {
            if (g_tree_lookup(b->ghost_tree, eptr)) {
                g_tree_remove(b->ghost_tree, eptr);
                QTAILQ_REMOVE(&set->ghost, eptr, b_entry);
                QTAILQ_INSERT_HEAD(&set->queue, eptr, b_entry);
                set->cnt_ghost--;
                set->cnt_main++;
                // printf("inserted ghost->main, lpn: 0x%lx\n", eptr->lpn);
            }
            else {
                QTAILQ_INSERT_HEAD(&set->small, eptr, b_entry);
                set->cnt_small++;
                // printf("inserted ->small, lpn: 0x%lx\n", eptr->lpn);
            }
            
        }
        eptr->freq = 0;
        g_tree_insert(b->tree, eptr, eptr);
        direct_mr_add(b, eptr->lpn);
        

        b->entry_cnt++;
        set->cnt++;
        
        assert(set->cnt == (set->cnt_main + set->cnt_small));

        return 1;
    }
    else {
        // printf("trapped hit, lpn: 0x%lx\n", eptr->lpn);
        direct_mr_add(b, eptr->lpn);
        freq_inc(eptr);
    }
    /* If the entry is already in buffer, just return*/
    return 0;
}

