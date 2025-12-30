#!/usr/bin/gnuplot
set terminal pdfcairo enhanced color size 5.65,2.25 font "Helvetica,20"
set output OUT

set title "Cylon vs. CMM-H Bandwidth" offset 0,-.8
set xlabel "Normalized WSS to DRAM Cache Size" offset 0,1
set ylabel "Bandwidth (MB/s)" offset 1.9,0
set key top right font ",20"

set style data linespoints
set pointsize 0.9

set style line 1 lt 1 lw 4 pt 7 ps 1.2 lc rgb "orange"
set style line 2 lt 1 lw 4 pt 5 ps 1.2 lc rgb "navy"

plot \
  TABLE using 1:2 title "Cylon" ls 1, \
  TABLE using 1:3 title "CMM-H" ls 2