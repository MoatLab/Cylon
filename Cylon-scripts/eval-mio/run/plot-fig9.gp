#!/usr/bin/gnuplot

#load 'mc.gp'
set terminal pdfcairo enhanced color size 11.6,2 font "Helvetica,20"
set output "../plot/mio-eviction.pdf"

#set datafile separator ","
set multiplot layout 1,5 margins 0.05, 0.985, 0.215, 0.87 spacing 0.05, 0.19

set style line 1  lt 1 dashtype 2 lw 3 pt 1  ps 1.2 lc rgb "#e377c2"  # pink
set style line 2  lt 1 dashtype 2 lw 3 pt 4  ps 1.2 lc rgb "#17becf"  # cyan
set style line 3  lt 1 dashtype 2 lw 3 pt 11 ps 1.2 lc rgb "#9467bd"  # purple
set style line 4  lt 1 dashtype 2 lw 3 pt 3  ps 1.2 lc rgb "#8c564b"  # brown
set style line 5  lt 1 lw 3 pt 7  ps 1.2 lc rgb "#1f77b4"  # blue
set style line 6  lt 1 lw 3 pt 5  ps 1.2 lc rgb "#ff7f0e"  # orange
set style line 7  lt 1 lw 3 pt 9  ps 1.2 lc rgb "#2ca02c"  # green
set style line 8  lt 1 lw 3 pt 13 ps 1.2 lc rgb "#d62728"  # red

set style line 1  lt 1 lw 3 pt 7  ps 1.2 lc rgb "#0073c6ff"  # blue
set style line 2  lt 1 lw 3 pt 5  ps 1.2 lc rgb "#ff7f0e"  # orange
set style line 3  lt 1 lw 3 pt 9  ps 1.2 lc rgb "#2ca02c"  # green
set style line 4  lt 1 lw 3 pt 3  ps 1.2 lc rgb "#d62728"  # red


set key bottom right font ",18" samplen 1.6
set xrange [0:20000]
set yrange [0:]
set xtics 10000
set ytics 0.2 font ", 20"
set xtics font ",20" offset 0,0.3
set xlabel "Time (ns)" offset 0,.9 font ",20"
set ylabel "CDF" offset 1.9,0 font ",20"

#set grid ls 101
set title "[a] Seq" font ",20" offset 0,-0.7

plot \
'../dat/FIFO-NAND2/N0m1_t1_b8192_s64.dat' w l ls 1 lw 9 title "FIFO", \
'../dat/LIFO-NAND2/N0m1_t1_b8192_s64.dat' w l ls 2 lw 5 title "LIFO", \
'../dat/CLOCK-NAND2/N0m1_t1_b8192_s64.dat' w l ls 3 lw 5 title "CLOCK", \
'../dat/S3FIFO-NAND2/N0m1_t1_b8192_s64.dat' w l ls 4 lw 3 title "S3-FIFO", \

unset key
set xrange [0:60000]
set yrange [0:]
set xtics 25000
#set ylabel "Count (K)"
unset ylabel

#set grid ls 101
set title "[b] Rand" offset 0,-0.7

plot \
'../dat/FIFO-NAND2/N0m1_t1_b8192_s64-R.dat' w l ls 1 lw 9 title "FIFO", \
'../dat/LIFO-NAND2/N0m1_t1_b8192_s64-R.dat' w l ls 2 lw 5 title "LIFO", \
'../dat/CLOCK-NAND2/N0m1_t1_b8192_s64-R.dat' w l ls 3 lw 5 title "CLOCK", \
'../dat/S3FIFO-NAND2/N0m1_t1_b8192_s64-R.dat' w l ls 4 lw 3 title "S3-FIFO"

set xrange [0:10000]
set yrange [0:]
set xtics 5000
#set ylabel "Count (K)"
unset ylabel

set title "[c] Stride-512" offset 0,-0.7

plot \
'../dat/FIFO-NAND2/N0m1_t1_b8192_s512.dat' w l ls 1 lw 9 title "FIFO", \
'../dat/LIFO-NAND2/N0m1_t1_b8192_s512.dat' w l ls 2 lw 5 title "LIFO", \
'../dat/CLOCK-NAND2/N0m1_t1_b8192_s512.dat' w l ls 3 lw 5 title "CLOCK", \
'../dat/S3FIFO-NAND2/N0m1_t1_b8192_s512.dat' w l ls 4 lw 3 title "S3-FIFO", \

set xrange [0:20000]
set yrange [0:]
set xtics 10000
#set ylabel "Count (K)"
unset ylabel

#set grid ls 101
set title "[d] Stride-1024" offset 0,-0.7

plot \
'../dat/FIFO-NAND2/N0m1_t1_b8192_s1024.dat' w l ls 1 lw 9  title "FIFO", \
'../dat/LIFO-NAND2/N0m1_t1_b8192_s1024.dat' w l ls 2 lw 5  title "LIFO", \
'../dat/CLOCK-NAND2/N0m1_t1_b8192_s1024.dat' w l ls 3 lw 5  title "CLOCK", \
'../dat/S3FIFO-NAND2/N0m1_t1_b8192_s1024.dat' w l ls 4 lw 3  title "S3-FIFO"

set xrange [0:70000]
set yrange [0:]
set xtics 30000
set title "[e] Stride-4096" offset 0,-0.7

plot \
'../dat/FIFO-NAND2/N0m1_t1_b8192_s4096.dat' w l ls 1 lw 9 title "FIFO", \
'../dat/LIFO-NAND2/N0m1_t1_b8192_s4096.dat' w l ls 2 lw 5  title "LIFO", \
'../dat/CLOCK-NAND2/N0m1_t1_b8192_s4096.dat' w l ls 3 lw 5  title "CLOCK", \
'../dat/S3FIFO-NAND2/N0m1_t1_b8192_s4096.dat' w l ls 4 lw 3  title "S3-FIFO"

