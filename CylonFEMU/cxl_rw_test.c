#include <stdlib.h>
#include <stdio.h>
#include <assert.h>
#include <unistd.h>
#include <sys/time.h>
#include <fcntl.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/mman.h>
#include <sys/syscall.h>
#include <sys/ioctl.h>
#include <stdint.h>
#include <time.h>
// #include <cxl/libcxl.h>


#define MMAP_SIZE (uint64_t)(1<<30) // 1GiB

double time_diff(struct timeval x, struct timeval y)
{
    double x_ms , y_ms , diff;
      
    x_ms = (double)x.tv_sec*1000000 + (double)x.tv_usec;
    y_ms = (double)y.tv_sec*1000000 + (double)y.tv_usec;
      
    diff = (double)y_ms - (double)x_ms;
      
    return diff;
}


void do_seq_read(void *ptr, uint64_t wsize)
{
    uint64_t a;
    uint64_t bytes_read;

    struct timeval stime, etime;
    for (bytes_read=0; bytes_read < wsize; bytes_read+=sizeof(uint64_t)) {
        gettimeofday(&stime, NULL);
        a = *(uint64_t*)(ptr+bytes_read);
        gettimeofday(&etime, NULL);
        printf("%0.03f ", time_diff(stime, etime));
    }
    printf("\n");
}

void do_seq_write(void *ptr, uint64_t wsize)
{
    uint64_t a = 0xAB00CD00EF000000;
    uint64_t bytes_read;

    struct timeval stime, etime;
    for (bytes_read=0; bytes_read < wsize; bytes_read+=sizeof(uint64_t)) {
        gettimeofday(&stime, NULL);
        *(uint64_t*)(ptr+bytes_read) = a;
        gettimeofday(&etime, NULL);
        printf("%0.03f ", time_diff(stime, etime));
    }
}

void do_hop_read(void *ptr, uint64_t wsize)
{
    uint64_t a;
    uint64_t bytes_read;

    struct timeval stime, etime;
    for (bytes_read=0; bytes_read < wsize; bytes_read+=sizeof(uint64_t)) {
        gettimeofday(&stime, NULL);
        a = *(uint64_t*)(ptr+(rand() % wsize));
        gettimeofday(&etime, NULL);
        printf("%0.03f ", time_diff(stime, etime));
    }
    printf("\n");
}

void do_hop_write(void *ptr, uint64_t wsize)
{
    uint64_t a = 0xAB00CD00EF000000;
    uint64_t bytes_read;

    struct timeval stime, etime;
    for (bytes_read=0; bytes_read < wsize; bytes_read+=sizeof(uint64_t)) {
        gettimeofday(&stime, NULL);
        *(uint64_t*)(ptr+(rand() % wsize)) = a;
        gettimeofday(&etime, NULL);
        printf("%0.03f ", time_diff(stime, etime));
    }
    printf("\n");
}

void print_res(char *name, double time, uint64_t wsize)
{
    printf("\t[%s]\t%.01fs, BW:%5.03fMB/s, Lat:%0.03fus/8B\n",name, time / 1000000 , wsize / (time) * 1000000 / 1024 / 1024, time/wsize * 8);
}

int main(){
    
    int fd = open("/dev/dax0.0", O_RDWR);
    if (fd < 0) {
        perror("open: ");
        exit(0);
    }

    time_t t;
    srand(1024);

    uint64_t workload_size = (1 << 29);
    void *ptr;    
    struct timeval stime, etime;

    printf("mmap size: %ldMiB, Workload size: %ldMiB\n", MMAP_SIZE / 1024 / 1024, workload_size / 1024 / 1024);

    void *dram = malloc(workload_size);
    ptr = dram;
    gettimeofday(&stime, NULL);
    do_seq_read(ptr, workload_size);
    gettimeofday(&etime, NULL);
    print_res("DRAM seq read ", time_diff(stime, etime), workload_size);
    
    gettimeofday(&stime, NULL);
    do_seq_write(ptr, workload_size);
    gettimeofday(&etime, NULL);
    print_res("DRAM seq write", time_diff(stime, etime), workload_size);
    
    gettimeofday(&stime, NULL);
    do_hop_read(ptr, workload_size);
    gettimeofday(&etime, NULL);
    print_res("DRAM hop read ", time_diff(stime, etime), workload_size);

    gettimeofday(&stime, NULL);
    do_hop_write(ptr, workload_size);
    gettimeofday(&etime, NULL);
    print_res("DRAM hop write", time_diff(stime, etime), workload_size);

    void *cxl = mmap(NULL, MMAP_SIZE, PROT_READ|PROT_WRITE, MAP_SHARED, fd, 0);
    if (cxl == MAP_FAILED) {
        perror("mmap: ");
        exit(0);
    }
    ptr = cxl;
    gettimeofday(&stime, NULL);
    do_seq_read(ptr, workload_size);
    gettimeofday(&etime, NULL);
    print_res("CXLSSD seq read", time_diff(stime, etime), workload_size);
    
    gettimeofday(&stime, NULL);
    do_seq_write(ptr, workload_size);
    gettimeofday(&etime, NULL);
    print_res("CXLSSD seq write", time_diff(stime, etime), workload_size);
    
    gettimeofday(&stime, NULL);
    do_hop_read(ptr, workload_size);
    gettimeofday(&etime, NULL);
    print_res("CXLSSD hop read", time_diff(stime, etime), workload_size);

    gettimeofday(&stime, NULL);
    do_hop_write(ptr, workload_size);
    gettimeofday(&etime, NULL);
    print_res("CXLSSD hop write", time_diff(stime, etime), workload_size);   
    


    
    munmap(cxl, MMAP_SIZE);
    munmap(dram, MMAP_SIZE);


    // close(fd);
    return 0;
}
