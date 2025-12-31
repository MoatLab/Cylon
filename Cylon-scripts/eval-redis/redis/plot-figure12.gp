set terminal pdfcairo enhanced color size 5.35,2.05 font "Helvetica,18"
set output OUT

set style line 1  lt 1 lw 8 lc rgb "#882255"
set style line 2  lt 1 lw 7 lc rgb "#aa4499"
set style line 3  lt 1 lw 6 lc rgb "#cc6677"
set style line 4  lt 1 lw 5 lc rgb "#ddcc77"
set style line 5  lt 1 lw 4 lc rgb "#88ccee"

set multiplot layout 1,2 margins 0.1, 0.96, 0.2, 0.86 spacing 0.07, 0.1

set key bottom right offset .5,0 samplen 2
set yrange [0:]
set ytics 0.2
set xtics offset 0,.5
set xlabel "Time (µs)" offset 0,.85
set ylabel "CDF" offset 1.9,0

# Panel (a): 1,000,000
set title "[a] 0.33 Norm. WSS" offset 0,-0.7
set xrange [0:200]
plot \
  sprintf("%s/%d-%s-1000000-0_run.log.dat", DATDIR, T, DIST) w l ls 1 title "0", \
  sprintf("%s/%d-%s-1000000-1_run.log.dat", DATDIR, T, DIST) w l ls 2 title "1", \
  sprintf("%s/%d-%s-1000000-2_run.log.dat", DATDIR, T, DIST) w l ls 3 title "2", \
  sprintf("%s/%d-%s-1000000-4_run.log.dat", DATDIR, T, DIST) w l ls 4 title "4", \
  sprintf("%s/%d-%s-1000000-8_run.log.dat", DATDIR, T, DIST) w l ls 5 title "8"

# Panel (b): 6,000,000
unset key
unset ylabel
set title "[b] 2.10 Norm. WSS"
set xrange [0:3000]
set xtics 1000
plot \
  sprintf("%s/%d-%s-6000000-0_run.log.dat", DATDIR, T, DIST) w l ls 1 title "0", \
  sprintf("%s/%d-%s-6000000-1_run.log.dat", DATDIR, T, DIST) w l ls 2 title "1", \
  sprintf("%s/%d-%s-6000000-2_run.log.dat", DATDIR, T, DIST) w l ls 3 title "2", \
  sprintf("%s/%d-%s-6000000-4_run.log.dat", DATDIR, T, DIST) w l ls 4 title "4", \
  sprintf("%s/%d-%s-6000000-8_run.log.dat", DATDIR, T, DIST) w l ls 5 title "8"

unset multiplot