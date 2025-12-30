# MoatLab common style settings for gnuplot

#-------------------------------------------------------------------------------
# Global variables for certain settings
mfontsize = 12 # default font size
mlw=3 # default line width

# Default multiplot layout (can be overridden in plot script)
mrows = 2
mcols = 2
plotspacing_x = 0.05
plotspacing_y = 0.07
tmargin_multiplot = 0.94
bmargin_multiplot = 0.12
lmargin_multiplot = 0.10
rmargin_multiplot = 0.98

#
#set multiplot layout mrows, mcols margins lmargin_multiplot, rmargin_multiplot, bmargin_multiplot, tmargin_multiplot spacing plotspacing_x, plotspacing_y

# Line Styles
set style line 1  lt 1 lw mlw pt 7  ps 1.2 lc rgb "#1f77b4"  # blue
set style line 2  lt 1 lw mlw pt 5  ps 1.2 lc rgb "#ff7f0e"  # orange
set style line 3  lt 1 lw mlw pt 9  ps 1.2 lc rgb "#2ca02c"  # green
set style line 4  lt 1 lw mlw pt 13 ps 1.2 lc rgb "#d62728"  # red
set style line 5  lt 1 lw mlw pt 11 ps 1.2 lc rgb "#9467bd"  # purple
set style line 6  lt 1 lw mlw pt 3  ps 1.2 lc rgb "#8c564b"  # brown
set style line 7  lt 1 lw mlw pt 6  ps 1.2 lc rgb "#e377c2"  # pink
set style line 8  lt 1 lw mlw pt 12 ps 1.2 lc rgb "#7f7f7f"  # medium gray
set style line 9  lt 1 lw mlw pt 10 ps 1.2 lc rgb "#bcbd22"  # yellow-green
set style line 10 lt 1 lw mlw pt 4  ps 1.2 lc rgb "#17becf"  # teal
set style line 11 lt 1 lw mlw pt 8  ps 1.2 lc rgb "#393b79"  # dark blue
set style line 12 lt 1 lw mlw pt 2  ps 1.2 lc rgb "#637939"  # olive green
set style line 13 lt 1 lw mlw pt 14 ps 1.2 lc rgb "#8c6d31"  # golden brown
set style line 14 lt 1 lw mlw pt 1  ps 1.2 lc rgb "#000000"  # black
set style line 15 lt 1 lw mlw pt 15 ps 1.2 lc rgb "#aaaaaa"  # light gray

# Grid
set style line 101 lt 1 lw 0.5 lc rgb "#aaaaaa"
#set grid ytics ls 101

# Axes, Tics, and Legend
set border # Use 3 to remove top and right borders
set key top right box
set xtics scale .5 nomirror # out
set ytics scale .5 nomirror # out

# Font & Label Offsets
set xlabel offset 0,0.5
set ylabel offset 1.5,0
set title offset 0,-0.8

labelfont = sprintf(",%d", mfontsize - 1)
ticfont   = sprintf(",%d", mfontsize - 2)
titlefont = sprintf(",%d", mfontsize)
set title  font titlefont
set xlabel font labelfont
set ylabel font labelfont
set tics   font ticfont


# Tighter Margins (screen coords 0-1)
set lmargin at screen 0.10
set rmargin at screen 0.98
set tmargin at screen 0.94
set bmargin at screen 0.12
