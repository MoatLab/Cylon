### prefetch_vs_wss.gnuplot
set terminal pdfcairo enhanced color size 5.65,2.25 font "Helvetica,20"
set output 'plot/cylon-cmmh-mlc.pdf'

# set multiplot layout 1,3 margins 0.083, 0.96, 0.32, 0.85 spacing 0.04, 0.1
set title "Cylon vs. CMM-H Bandwidth " offset 0, -.8
set xlabel "Normalized WSS to DRAM Cache Size" offset 0,1
set ylabel "Bandiwdth (MB/s)" offset 1.9,0
#set grid ytics xtics
set key top right font ",20"
set style data linespoints
set pointsize 0.9
# set logscale x 2   # nice spacing for 2,4,8,...128

set ytics 10000 offset .7,0
set xtic offset 0,.5

set tmargin 1.35
set lmargin 7.5
set rmargin 1.1

# Define line styles
set style line 1  lt 1 dashtype 2 lw 3 pt 1  ps 1.2 lc rgb "#e377c2"  # pink
set style line 2  lt 1 dashtype 2 lw 3 pt 4  ps 1.2 lc rgb "#17becf"  # cyan
set style line 3  lt 1 dashtype 2 lw 3 pt 11 ps 1.2 lc rgb "#9467bd"  # purple
set style line 4  lt 1 dashtype 2 lw 3 pt 3  ps 1.2 lc rgb "#8c564b"  # brown
set style line 5  lt 1 lw 3 pt 7  ps 1.2 lc rgb "#1f77b4"  # blue
set style line 6  lt 1 lw 3 pt 5  ps 1.2 lc rgb "#ff7f0e"  # orange
set style line 7  lt 1 lw 3 pt 9  ps 1.2 lc rgb "#2ca02c"  # green
set style line 8  lt 1 lw 3 pt 13 ps 1.2 lc rgb "#d62728"  # red


# Inline data table:  columns -> WSS  pre0 pre1 pre2 pre4 pre8 CMMH
$DATA << EOD
WSS   P0      P1      P2      P4      P8      CMM
0.04  33765   33775.7 33789.7 33761.2 33785.5 22345.5
0.08  33742.2 33675.6 33775.4 33733.5 33786.8 22189.1
0.17  33733.8 33617.5 33761.7 33733.8 33773   22076.8
0.33  33761.6 33738.8 33762.5 33744.6 33782.4 21481.8
0.67  33717.5 20569.7 33731.1 33748.4 33736   2630.3
1.33  78      155.2   376.7   380     1273.6  1112.6
2.67  78      154.3   233.7   379.8   695.2   835.2
EOD

plot \
    $DATA using 1:2   title "Cylon"  ls 5 lw 5 lc rgb "orange", \
    $DATA using 1:7  title "CMM-H"  ls 6 lw 5 lc rgb "navy"
    # $DATA using 1:3  title "Cylon"  ls 5, \
    # $DATA using 1:2  title "Cylon 0"  ls 1, \
    
    # $DATA using 1:4  title "Prefetch 2"  ls 3, \
    # $DATA using 1:5  title "Prefetch 4"  ls 4, \
    # $DATA using 1:6  title "Prefetch 8"  ls 5, \
    


