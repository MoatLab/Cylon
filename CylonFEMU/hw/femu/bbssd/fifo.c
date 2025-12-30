#include "buffer.h"


int fifo_evict_victim(struct buffer *b, struct set *set)
{
    struct buffer_entry *victim = NULL;

	if (b->way == WAY_1) {
		victim = set->entry;
	}
	else {
		victim = QTAILQ_FIRST(&set->queue);

		if(!victim){
			return -1;
		}
		QTAILQ_REMOVE(&set->queue, victim, b_entry);	//remove from queue
	}
	
	if (victim == NULL)
		return -1;

	// printf("evict 0x%lx, set idx: 0x%lx\n", victim->lpn, victim->lpn & (b->set_mask));
	// fflush(stdout);

	/* Flush page to NAND */
	flush_pg(b->ssd, victim->lpn);

	g_tree_remove(b->tree, victim);	//remove from avl tree
	direct_mr_del(b, victim->lpn);

	free(victim);
	b->entry_cnt--;
	set->cnt--;

	return 1;
}

// static int a = 1;
int fifo_insert_entry(struct buffer *b, struct buffer_entry *eptr)
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
			fifo_evict_victim(b, set);
		}
		
		//insert entry
		if (b->way == WAY_1) {
			set->entry = eptr;
		}
		else {
			QTAILQ_INSERT_TAIL(&set->queue, eptr, b_entry);
		}
		g_tree_insert(b->tree, eptr, eptr);
		direct_mr_add(b, eptr->lpn);

		b->entry_cnt++;
		set->cnt++;
		
		return 1;
	}
	else {
        // printf("trapped hit, lpn: 0x%lx\n", eptr->lpn);
        direct_mr_add(b, eptr->lpn);
    }
	/* If the entry is already in buffer, just return*/
	return 0;
}

