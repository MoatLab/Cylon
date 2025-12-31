#!/usr/bin/gnuplot

set style line 1 lw 3 lc rgb '#0F1F3D'
set style line 2 lw 3 lc rgb '#1B365D'
set style line 3 lw 3 lc rgb '#4472C4'
set style line 4 lw 3 lc rgb '#A5C0E6'

set style line 5 lw 3 lc rgb '#8B4513'
set style line 6 lw 3 lc rgb '#B8651B'
set style line 7 lw 3 lc rgb '#ED7D31'
set style line 8 lw 3 lc rgb '#F6C8A4'

set  style line 9 lw 3 dashtype 2 lc rgb '#0F1F3D'
set  style line 10 lw 3 dashtype 2 lc rgb '#1B365D'
set  style line 11 lw 3 dashtype 2 lc rgb '#4472C4'
set  style line 12 lw 3 dashtype 2 lc rgb '#A5C0E6'

set  style line 13 lw 3 dashtype 2 lc rgb '#8B4513'
set  style line 14 lw 3 dashtype 2 lc rgb '#B8651B'
set  style line 15 lw 3 dashtype 2 lc rgb '#ED7D31'
set  style line 16 lw 3 dashtype 2 lc rgb '#F6C8A4'

set terminal pdfcairo enhanced color size 4.1,1.5 font "Helvetica,16"
set output "../plot/figure3.pdf"

#set multiplot layout 1,2 margins screen 0.1, 0.93, 0.3, 0.87 spacing 0.14,0
set tmargin 0.7
set bmargin 2
set lmargin 5.5
set rmargin 1.0

set ytics 0.2 offset .7,0
set ylabel "CDF" offset 2.2,0
set xlabel "Latency (ns)"  offset 0,1
set logscale x
set xrange [1:10000]
set xtics offset 0,.5
set yrange [0:]

set key left top samplen 2
set key font ",16"
unset grid

set xrange [1:40000]

mean_linear = real(system("./calc_mean.sh ../dat/linear/N0m1_t8_b8192.dat"))
mean_qemu = real(system("./calc_mean.sh ../dat/qemu/N0m1_t8_b8192.dat"))

set arrow 2 from mean_linear,0 to mean_linear,1 nohead lc rgb "orange" lw 4 dt 2 front
set arrow 3 from mean_qemu,0 to mean_qemu,1 nohead lc rgb "#2ca02c" lw 4 dt 2 front

set label 2 sprintf("Avg: %.0f", mean_linear) at mean_linear,0.5 right offset -0.5,0 font ",16" tc rgb "orange"
set label 3 sprintf("Avg: %.0f", mean_qemu) at mean_qemu,0.65 right offset -0.5,0 font ",16" tc rgb "#2ca02c"

plot\
     "../dat/linear/N0m1_t8_b8192.dat" with lines lw 5 lc rgb "orange" title "Cylon", \
     "../dat/qemu/N0m1_t8_b8192.dat" with lines lw 5 lc rgb "#2ca02c" title "QEMU"

