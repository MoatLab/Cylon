#!/usr/bin/gnuplot
#load 'mc.gp'
set terminal pdfcairo enhanced color size 4.65,2.25 font "Helvetica,18"
set output "../plot/latency-breakdown.pdf"
set style fill solid 1
set style data histograms
set style histogram rowstacked
set boxwidth 0.5 relative

#set style line 1 lc rgb "#54585A"    # Native DDR
#set style line 2 lc rgb "#228B22"        # Base Virt
#set style line 3 lc rgb "#08519c"    # IOCTL
#set style line 4 lc rgb "orange"    # QEMU
#set style line 5 lc rgb "#a63603"    # VM Exit
#set style line 6 lc rgb "#6a3d9a"    # Others

set style line 1 lc rgb "#93ab52"    # Native DDR
set style line 2 lc rgb "#f2cf5c"        # Base Virt
set style line 3 lc rgb "#f2cf5c"    # IOCTL
set style line 4 lc rgb "#ec773d"    # QEMU
set style line 5 lc rgb "#b83530"    # VM Exit
set style line 6 lc rgb "#722030"    # Others

set bmargin 1.9
set lmargin 5.1
set rmargin 1.1
#set title "Remote NUMA Latency Breakdown" font 'Helvetica,14'
set ylabel "Latency (μs)" offset 1.7, 0
set yrange [0:26]
set ytics 3 offset .35, 0
#set xlabel "Configuration" font 'Helvetica,20'
set xtics center font "Helvetica,16" offset 0,.5 
set key left top font 'Helvetica,16' samplen 1.75 offset -0.5, 0
#set xtics nomirror
set auto x

# Plot with labels only for values > 1000
plot '../dat/data.dat' using ($2/1000):xtic(1) ls 1 title "Native DDR", \
     '' using ($4/1000) ls 2 title "KVM", \
     '' using ($5/1000) ls 4 title "QEMU", \
     '' using ($6/1000) ls 5 title "FTL", \
     '' using ($7/1000) ls 6 title "IOCTL", \
     '' u 0:($2/2):($2 > 500 ? sprintf("%.1f", $2/1000) : "") w labels font "Helvetica,16" tc rgb "white" notitle, \
     '' u 0:(($2+$3/2)/1000):($3 > 500 ? sprintf("%.1f", $3/1000) : "") w labels font "Helvetica,16" tc rgb "white" notitle, \
     '' u 0:(($2+$3+$4/2)/1000):($4 > 500 ? sprintf("%.1f", $4/1000) : "") w labels font "Helvetica,16" tc rgb "white" notitle, \
     '' u 0:(($2+$3+$4+$5/2)/1000):($5 > 500 ? sprintf("%.1f", $5/1000) : "") w labels font "Helvetica,16" tc rgb "white" notitle, \
     '' u 0:(($2+$3+$4+$5+$6/2)/1000):($6 > 500 ? sprintf("%.1f", $6/1000) : "") w labels font "Helvetica,16" tc rgb "white" notitle, \
     '' u 0:(($2+$3+$4+$5+$6+$7/2)/1000):($7 > 500 ? sprintf("%.1f", $7/1000) : "") w labels font "Helvetica,16" tc rgb "white" notitle, \
     '' u 0:(($2+$3+$4+$5+$6+$7)/1000 + 1.5):(sprintf("%.2f", ($2+$3+$4+$5+$6+$7)/1000)) w labels font "Helvetica,16" tc rgb "black" notitle
    
#     '' using ($4/1000) ls 3 title "Overhead", \

