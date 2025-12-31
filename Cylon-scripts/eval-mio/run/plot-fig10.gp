#!/usr/bin/gnuplot

#load 'mc.gp'
set terminal pdfcairo enhanced color size 11.6,2 font "Helvetica,18"
set output "../plot/prefetching-fifo.pdf"

#set datafile separator ","
set multiplot layout 1,5 margins 0.05, 0.98, 0.20, 0.89 spacing 0.05, 0.15

set style line 1  lt 1 dashtype 2 lw 3 pt 1  ps 1.2 lc rgb "#e377c2"  # pink
set style line 2  lt 1 dashtype 2 lw 3 pt 4  ps 1.2 lc rgb "#17becf"  # cyan
set style line 3  lt 1 dashtype 2 lw 3 pt 11 ps 1.2 lc rgb "#9467bd"  # purple
set style line 4  lt 1 dashtype 2 lw 3 pt 3  ps 1.2 lc rgb "#8c564b"  # brown
set style line 5  lt 1 lw 3 pt 7  ps 1.2 lc rgb "#1f77b4"  # blue
set style line 6  lt 1 lw 3 pt 5  ps 1.2 lc rgb "#ff7f0e"  # orange
set style line 7  lt 1 lw 3 pt 9  ps 1.2 lc rgb "#2ca02c"  # green
set style line 8  lt 1 lw 3 pt 13 ps 1.2 lc rgb "#d62728"  # red

set style line 1  lt 1 lw 8 pt 7  ps 1.2 lc rgb "#882255"
set style line 2  lt 1 lw 7 pt 5  ps 1.2 lc rgb "#aa4499"
set style line 3  lt 1 lw 6 pt 9  ps 1.2 lc rgb "#cc6677" 
set style line 4  lt 1 lw 5 pt 3  ps 1.2 lc rgb "#ddcc77"
set style line 5  lt 1 lw 4 pt 3  ps 1.2 lc rgb "#88ccee"

set key bottom right font ",18" offset 0.9,0
set xrange [0:10000]
set yrange [0:]
set ytics 0.2 offset .15,0 
set xtics 5000 offset 0,0.5
set xlabel "Time (ns)" offset 0,0.9
set ylabel "CDF" offset 1.95,0 

#set grid ls 101
set title "[a] Seq" font ",18" offset 0,-0.75


plot \
'../dat/S3FIFO_prefetch/N0m1_t1_b8192_s64_p0.dat' w l ls 1 title "0", \
'../dat/S3FIFO_prefetch/N0m1_t1_b8192_s64_p1.dat' w l ls 2 title "1", \
'../dat/S3FIFO_prefetch/N0m1_t1_b8192_s64_p2.dat' w l ls 3 title "2", \
'../dat/S3FIFO_prefetch/N0m1_t1_b8192_s64_p4.dat' w l ls 4 title "4", \
'../dat/S3FIFO_prefetch/N0m1_t1_b8192_s64_p8.dat' w l ls 5 title "8"

unset key
set xrange [0:60000]
set yrange [0:]
set xtics 25000
#set ylabel "Count (K)"
unset ylabel

#set grid ls 101
set title "[b] Rand" 

plot \
'../dat/S3FIFO_prefetch/N0m1_t1_b8192_s64_p0-R.dat' w l ls 1 title "0", \
'../dat/S3FIFO_prefetch/N0m1_t1_b8192_s64_p1-R.dat' w l ls 2 title "1", \
'../dat/S3FIFO_prefetch/N0m1_t1_b8192_s64_p2-R.dat' w l ls 3 title "2", \
'../dat/S3FIFO_prefetch/N0m1_t1_b8192_s64_p4-R.dat' w l ls 4 title "4", \
'../dat/S3FIFO_prefetch/N0m1_t1_b8192_s64_p8-R.dat' w l ls 5 title "8"

set xrange [0:10000]
set yrange [0:]
set xtics 5000
#set ylabel "Count (K)"
unset ylabel

set title "[c] Stride-512" 

plot \
'../dat/S3FIFO_prefetch/N0m1_t1_b8192_s512_p0.dat' w l ls 1 title "0", \
'../dat/S3FIFO_prefetch/N0m1_t1_b8192_s512_p1.dat' w l ls 2 title "1", \
'../dat/S3FIFO_prefetch/N0m1_t1_b8192_s512_p2.dat' w l ls 3 title "2", \
'../dat/S3FIFO_prefetch/N0m1_t1_b8192_s512_p4.dat' w l ls 4 title "4", \
'../dat/S3FIFO_prefetch/N0m1_t1_b8192_s512_p8.dat' w l ls 5 title "8"

set xrange [0:20000]
set yrange [0:]
set xtics 10000
#set ylabel "Count (K)"
unset ylabel

#set grid ls 101
set title "[d] Stride-1024" 
plot \
'../dat/S3FIFO_prefetch/N0m1_t1_b8192_s1024_p0.dat' w l ls 1 title "0", \
'../dat/S3FIFO_prefetch/N0m1_t1_b8192_s1024_p1.dat' w l ls 2 title "1", \
'../dat/S3FIFO_prefetch/N0m1_t1_b8192_s1024_p2.dat' w l ls 3 title "2", \
'../dat/S3FIFO_prefetch/N0m1_t1_b8192_s1024_p4.dat' w l ls 4 title "4", \
'../dat/S3FIFO_prefetch/N0m1_t1_b8192_s1024_p8.dat' w l ls 5 title "8"

set xrange [0:70000]
set yrange [0:]
set xtics 30000
set title "[e] Stride-4096"

plot \
'../dat/S3FIFO_prefetch/N0m1_t1_b8192_s4096_p0.dat' w l ls 1 title "0", \
'../dat/S3FIFO_prefetch/N0m1_t1_b8192_s4096_p1.dat' w l ls 2 title "1", \
'../dat/S3FIFO_prefetch/N0m1_t1_b8192_s4096_p2.dat' w l ls 3 title "2", \
'../dat/S3FIFO_prefetch/N0m1_t1_b8192_s4096_p4.dat' w l ls 4 title "4", \
'../dat/S3FIFO_prefetch/N0m1_t1_b8192_s4096_p8.dat' w l ls 5 title "8"

