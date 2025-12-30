#include "utils.h"
#include <stdio.h>
#include <numa.h>
#include <numaif.h>
#include <stdlib.h>
#include <unistd.h>
#include <errno.h>
#include <fcntl.h>
#include <assert.h>
#include <time.h>

#include <string.h>
#include <sys/ioctl.h>
#include <sys/syscall.h>
#include <sys/mman.h>

void set_default(header_t* header) {
  header->print = 1;
  header->num_thread = 1;
  header->total_buf_size = (1 << 30);
  header->buf_a_numa_node = 0;
  header->op_iter = 5;
  header->per_thread_size = header->total_buf_size;
  header->starting_core = 0;
  header->random = false;
  header->halt = 0;
  header->tsc_freq = TSC_FREQ_GHZ;
  header->type = POINTER_CHASING;
  // header->stride_size = 64;
  header->num_chase_block = header->per_thread_size / sizeof(chase_t);
  assert(header->num_chase_block > 0);
  header->chase_interval = header->num_chase_block;
}

int parse_arg(int argc, char*argv[], header_t* header) {
  int opt;
  // int thread_num;
  // int read;
  // int write;
  set_default(header);

  while ((opt = getopt(argc, argv, "t:m:i:r:I:T:P:c:R")) != -1) {
    switch (opt) {
      case 't':
        header->num_thread = atoi(optarg);
        assert(header->num_thread > 0);
        break;
      case 'm':
        header->total_buf_size = ((uint64_t)atoi(optarg) * ((1 << 20)));
        // printf("%lu\n", header->total_buf_size);
        header->per_thread_size = header->total_buf_size;
        header->num_chase_block = header->per_thread_size / sizeof(chase_t);
        break;
      case 'i':
        header->op_iter = atoi(optarg);
        break;
      case 'r':
        header->buf_a_numa_node = atoi(optarg);
        break;
      case 'I':
        header->chase_interval = atoi(optarg);
        assert(header->num_chase_block % header->chase_interval == 0);
        break;
      case 'T':
        header->type = atoi(optarg);
        break;
      case 'P':
        header->print = atoi(optarg);
        break;
      case 'c':
        header->starting_core = atoi(optarg);
        break;
      case 'R':
        header->random = true;
        break;
      // case 's':
      //   header->stride_size = atoi(optarg);
      //   break;
    }
  }
  
  // header->num_chase_block = header->per_thread_size / header->stride_size;
  return 0;
}

#include <fcntl.h>
#define PAGEMAP_ENTRY 8             // Bytes per pagemap entry
#define PFN_MASK     ((1ULL << 55) - 1)
#define PAGE_SHIFT   12

static uint64_t virt_to_phys(uint64_t vaddr) {
  char pagemap_path[64];
  uint64_t file_offset, entry;
  int fd;

  fd = open("/proc/self/pagemap", O_RDONLY);
  if (fd < 0) {
    perror("open pagemap");
    return -1;
  }

  file_offset = (vaddr / sysconf(_SC_PAGESIZE)) * PAGEMAP_ENTRY;
  if (lseek(fd, file_offset, SEEK_SET) < 0) {
    perror("lseek pagemap");
    close(fd);
    return -1;
  }

  if (read(fd, &entry, PAGEMAP_ENTRY) != PAGEMAP_ENTRY) {
    perror("read pagemap");
    close(fd);
    return -1;
  }

  close(fd);

  // if (!(entry & (1ULL << 63))) {
  //             fprintf(stderr, "Page not present\n");
  // 	            return -1;
  // 		        }

  uint64_t pfn = entry & PFN_MASK;
  return (pfn << PAGE_SHIFT) | (vaddr & ((1ULL << PAGE_SHIFT) - 1));
}

// static uint64_t offset = 0;
static char *alloc(uint64_t size, int node, int tid) {
  char *ptr = NULL;
  uint64_t offset = size * tid;
  if (node == 0) {
    return (char *)numa_alloc_onnode(size, node);
  }
  else if (node == 1) {
    int fd = open("/dev/dax0.0", O_RDWR);
    if (fd < 0) {
      perror("open dax failed");
      exit(-1);
    }
    // fprintf(stderr, "%p [0x%lx] size 0x%lx\n", ptr, virt_to_phys(ptr), size);
    ptr = (char *)mmap(NULL, size, PROT_READ|PROT_WRITE, MAP_SHARED, fd, offset);
    fprintf(stderr, "zero buffer\n");
    memset(ptr, 0, size);
    fprintf(stderr, "%p [0x%lx] size 0x%lx\n", ptr, virt_to_phys(ptr), size);
    // close(fd);
    return ptr;
  }
  else {
    return NULL;
  }
}

int init_buf(uint64_t size, int node, char** alloc_ptr, int tid) {
  char *ptr;
  unsigned long page_size;
  uint64_t page_cnt;
  uint64_t idx;
  if ((ptr = alloc(size, node, tid)) == NULL) {
    fprintf(stderr,"ERROR: numa_alloc_onnode\n");
    return -1;
  }
  page_size = (unsigned long)getpagesize();
  page_cnt = (size / page_size);
  idx = 0;
  for (uint64_t i = 0; i < page_cnt; i++) {
    ptr[idx] = 0;
    idx += page_size;
  }
  *alloc_ptr = ptr;
  return 0;
}

void stop_threads(header_t* header_arr, int start_index) {
  int num_thread = header_arr[0].num_thread;
  for (int i = start_index; i < num_thread; i++) {
    header_arr[i].halt = 1;
  }
}
