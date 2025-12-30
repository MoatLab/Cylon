#include "buffer.h"

/* CLOCK (second chance)*/

static inline struct buffer_entry *clock_next(struct set *set, struct buffer_entry *cur)
{
    if (!cur) return QTAILQ_FIRST(&set->queue);
    struct buffer_entry *n = QTAILQ_NEXT(cur, b_entry);
    return n ? n : QTAILQ_FIRST(&set->queue);
}

int clock_evict_victim(struct buffer *b, struct set *set) {
    if (QTAILQ_EMPTY(&set->queue))
        return -1;

    if (!set->hand)
        set->hand = QTAILQ_FIRST(&set->queue);

    struct buffer_entry *ent = set->hand;

    /* scan until we find ref==0 */
    while (1) {
        if (!ent) { // should not happen if queue not empty, but be safe
            ent = QTAILQ_FIRST(&set->queue);
            if (!ent) return -1;
        }

        if (ent->ref == 0) {
            /* choose ent as victim; advance hand to next BEFORE removal */
            struct buffer_entry *next = clock_next(set, ent);

            /* Flush page to NAND (mirror of your FIFO path) */
            flush_pg(b->ssd, ent->lpn);

            /* remove from auxiliary indices */
            g_tree_remove(b->tree, ent);     // remove from avl tree
            direct_mr_del(b, ent->lpn);

            /* unlink from queue */
            QTAILQ_REMOVE(&set->queue, ent, b_entry);

            /* fix hand: if victim was only element, becomes NULL */
            if (QTAILQ_EMPTY(&set->queue)) {
                set->hand = NULL;
            } else {
                set->hand = (next == ent) ? QTAILQ_FIRST(&set->queue) : next;
            }

            free(ent);
            b->entry_cnt--;
            set->cnt--;
            return 1;
        } else {
            /* give second chance */
            ent->ref = 0;
            ent = clock_next(set, ent);
            set->hand = ent;
        }
    }
}

int clock_insert_entry(struct buffer *b, struct buffer_entry *eptr) {
    struct set *set = buffer_get_set(b, eptr->lpn);

    if (!g_tree_lookup(b->tree, eptr)) {

        int ent_max = 1 << b->way;
        if (b->way == WAY_FULL)
            ent_max = b->size;

        while (!(set->cnt < ent_max)) {
            if (clock_evict_victim(b, set) < 0)
                return -1;
        }

        /* initialize new entry’s ref bit (recently used) */
        eptr->ref = 1;

        /* place anywhere; tail is simple */
        QTAILQ_INSERT_TAIL(&set->queue, eptr, b_entry);

        /* initialize hand if queue was empty */
        if (!set->hand)
            set->hand = QTAILQ_FIRST(&set->queue);

        /* index it */
        g_tree_insert(b->tree, eptr, eptr);
        direct_mr_add(b, eptr->lpn);

        b->entry_cnt++;
        set->cnt++;
        return 1;
    }
    else {
        // printf("trapped hit, lpn: 0x%lx\n", eptr->lpn);
        direct_mr_add(b, eptr->lpn);
        /* already present: “use” it */
        struct buffer_entry *exist = g_tree_lookup(b->tree, eptr);
        if (exist) exist->ref = 1;
    }

    return 0;
}