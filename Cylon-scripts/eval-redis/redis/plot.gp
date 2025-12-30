#!/usr/bin/gnuplot
# Usage:
#   gnuplot -e "SMALL_DAT='...';MED_DAT='...';LARGE_DAT='...';CMMH_SMALL_DAT='...';CMMH_MED_DAT='...';CMMH_LARGE_DAT='...';OUT_PDF='../plot/out.pdf'" plot_1t_1m3m6m.gp

set style line 1 lt 1 lw 3 pt 7 ps 1.2 lc rgb "#1f77b4"
set style line 2 lt 1 lw 3 pt 5 ps 1.2 lc rgb "#ff7f0e"

set terminal pdfcairo enhanced color size 4.7,1.9 font "Helvetica,14"
set output OUT_PDF

set multiplot layout 1,3 margins 0.083, 0.96, 0.32, 0.85 spacing 0.04, 0.1

set key bottom right font ",12.5"
set ytics 0.2 font ",14"
set xtics font ",14"
set xlabel "Time (µs)" offset 0, -0.5 font ",14"
set ylabel "CDF" offset 1.9,0 font ",14"

# [a] Small
set title "[a] Small" font ",16" offset 0,-0.5
set xrange [0:200]
set yrange [0:]
plot \
  SMALL_DAT w l ls 1 title "Cylon", \
  CMMH_SMALL_DAT w l ls 2 title "CMM-H"

# [b] Medium
unset ylabel
unset ytics
set title "[b] Medium" font ",16" offset 0,-0.5
set xrange [0:600]
set yrange [0:]
set xtics 200
plot \
  MED_DAT w l ls 1 title "Cylon", \
  CMMH_MED_DAT w l ls 2 title "CMM-H"

# [c] Large
set title "[c] Large" font ",16" offset 0,-0.5
set xrange [0:1000]
set yrange [0:]
set xtics 250
plot \
  LARGE_DAT w l ls 1 title "Cylon", \
  CMMH_LARGE_DAT w l ls 2 title "CMM-H"

unset multiplot

