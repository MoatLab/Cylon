#!/usr/bin/gnuplot

#load 'mc.gp'

set style line 1  lt 1 lw 3 pt 7  ps 1.2 lc rgb "#1f77b4"  # blue
set style line 2  lt 1 lw 3 pt 5  ps 1.2 lc rgb "#ff7f0e"  # orange
set style line 3  lt 1 lw 3 pt 9  ps 1.2 lc rgb "#2ca02c"  # green
set style line 4  lt 1 lw 3 pt 3  ps 1.2 lc rgb "#d62728"  # red
set style line 5  lt 1 lw 3 pt 3  ps 1.2 lc rgb "#6a3d9a"  # red

set terminal pdfcairo enhanced color size 5.6,2.1 font "Helvetica,18"
set output "../plot/mio-cmmh-cylon-t4.pdf"

#set datafile separator ","


#                                right, left, bot, top
set multiplot layout 1,2 margins 0.09, 0.97, 0.2, 0.85 spacing 0.09, 0.1


#unset key
#unset xrange
set key bottom right
set xrange [0:35000]
set yrange [0.6:]
set xtics 10000
set ytics 0.1 font ", 18" offset 0.2,0
set xtics font ",18" offset 0,0.5
set xlabel "Time (ns)" font ",18" offset 0,1
set ylabel "CDF" offset 1.9,0 font ",18"

#set grid ls 101
set title "[a] 0.33 Norm. WSS" font ",18" offset 0,-0.5

plot \
'../dat/Cylon-FIFO-validation/N0m1_t4_b1638_s64.dat' w l ls 1 lw 5 lc rgb "orange" title "Cylon", \
'../dat/N0m2_t4_b16384.dat' w l ls 2 lw 5 lc rgb "navy" title "CMM-H", \

unset key
set xrange [0:35000]
set yrange [0.6:]
set xtics 10000
#set ylabel "Count (K)"
unset ylabel

#set grid ls 101
set title "[b] 2.10 Norm. WSS" font ",18" offset 0,-0.5

plot \
'../dat/Cylon-FIFO-validation/N0m1_t4_b6554_s64.dat' w l ls 1 lw 5 lc rgb "orange" title "Cylon", \
'../dat/N0m2_t4_b65536.dat' w l ls 2 lw 5 lc rgb "navy" title "CMM-H", \