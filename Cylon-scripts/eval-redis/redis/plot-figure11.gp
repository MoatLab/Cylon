#!/usr/bin/gnuplot

#load 'mc.gp'

#set style line 1  lt 1 lw 3 pt 7  ps 1.2 lc rgb "#1f77b4"  # blue
#set style line 2  lt 1 lw 3 pt 5  ps 1.2 lc rgb "#ff7f0e"  # orange
#set style line 3  lt 1 lw 3 pt 9  ps 1.2 lc rgb "#2ca02c"  # green
#set style line 4  lt 1 lw 3 pt 3  ps 1.2 lc rgb "#d62728"  # red

set style line 1  lt 1 lw 9 pt 7  ps 1.2 lc rgb "#0073c6ff"  # blue
set style line 2  lt 1 lw 5 pt 5  ps 1.2 lc rgb "#ff7f0e"  # orange
set style line 3  lt 1 lw 5 pt 9  ps 1.2 lc rgb "#2ca02c"  # green
set style line 4  lt 1 lw 3 pt 3  ps 1.2 lc rgb "#d62728"  # red

set terminal pdfcairo enhanced color size 5.35,2.05 font "Helvetica,18"
set output "../plot/redis-eviction-cylon.pdf"

#set datafile separator ","


#				 right, left, bot, top
set multiplot layout 1,2 margins 0.1, 0.97, 0.2, 0.86 spacing 0.07, 0.1


#unset key
#unset xrange
set key bottom right samplen 1.7 offset 0.5,0
set xrange [0:150]
set yrange [0:]
#set xtics 20000
set ytics 0.2 
set xtics offset 0,.5
set xlabel "Time (µs)" offset 0,1
set ylabel "CDF" offset 1.9,0 

#set grid ls 101
set title "[a] 0.33 Norm. WSS" font ",18" offset 0,-0.7

plot \
'../dat/figure11/fifo/fifo-1000000.dat' w l ls 1 title "FIFO", \
'../dat/figure11/lifo/lifo-1000000.dat' w l ls 2 title "LIFO", \
'../dat/figure11/clock/clock-1000000.dat' w l ls 3 title "CLOCK", \
'../dat/figure11/s3fifo/s3fifo-1000000.dat' w l ls 4 title "S3FIFO", \

unset key
set xrange [0:600]
set yrange [0:]
#set xtics 20000
#set ylabel "Count (K)"
unset ylabel

#set grid ls 101
set title "[b] 2.67 Norm. WSS" offset 0,-0.7

plot \
'../dat/figure11/fifo/fifo-6000000.dat' w l ls 1 title "FIFO", \
'../dat/figure11/lifo/lifo-6000000.dat' w l ls 2 title "LIFO", \
'../dat/figure11/clock/clock-6000000.dat' w l ls 3 title "CLOCK", \
'../dat/figure11/s3fifo/s3fifo-6000000.dat' w l ls 4 title "S3FIFO", \