# bc_latency.gnuplot
set terminal pdfcairo enhanced color size 5,2.6 font "Helvetica,18"
set output '../plot/cylon-cmmh-gapbs.pdf'

# set title "Betweenness Centrality (bc) Latency"

# set style histogram clustered gap 1
set boxwidth 1
set ylabel "Execution Time (s)" offset 1.5,0
set xlabel "Memory Footprint (GB)" offset 0,.3
#set grid ytics xtics 
set style data linespoints
set key bottom right
set xrange [1:3]
set style line 5  lt 1 lw 5 pt 7  ps 1.2 lc rgb "orange" 
set style line 6  lt 1 lw 5 pt 5  ps 1.2 lc rgb "navy"

set ytics 500 offset 0.5,0

set tmargin 0.7
set lmargin 7.5

$DATA << EOD
Scale    "CMM-H"    Cylon     
10.2      137.63451 120.31444 
20.4      301.46207 244.12642 
40.8      892.44486 493.64531

EOD
# Input data table: first column is graph scale, next two are Cylon and CMM-H latencies
# Missing value for Cylon at g29 is marked as "-"
plot \
    $DATA using 2:xtic(1) title "CMM-H"  ls 6, \
    $DATA using 3         title "Cylon" ls 5
