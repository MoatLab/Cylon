BEGIN {
    i = 0
    sum = 0
    sumsq = 0
    avg = 0
    median = 0
    min = 0
    max = 0
}

{
    i++
    lat[i] = $1
    sum += $1
    sumsq += ($1)^2
}

END {
    PROCINFO["sorted_in"] = "@ind_num_asc"

    min = lat[1]
    max = lat[i]
    avg = sum / i
    stddev = sqrt((sumsq-sum^2/NR)/NR)

    if (i % 2 == 0)
        median = (lat[i/2] + lat[i/2+1]) / 2
    else
        median = lat[(i+1)/2]

    # Min, Avg, Median, Max
    printf("%s,%d,%d,%d,%d,%.2f\n", FNAME, min, avg, median, max, stddev)


    #for (idx in cdf) {
    #    printf("%-10.6f\t%-10.6f\n", idx, cdf[idx]) >> "CDF"
    #}

    #cur = min

    #for (idx in cdf) {
    #    if (cdf[idx] < cdf[minNR] || cdf[idx] > cdf[maxNR]) {
    #        continue
    #    } else if ((cdf[idx] >= cur) && (cdf[idx] < cur + precision)) {
    #        printf("%-16.6f\t%-10.6f\n", idx, cdf[idx]) >> output
    #        cur += precision
    #    } else if (cdf[idx] >= cur + precision) {
    #        printf("%-16.6f\t%-10.6f\n", idx, cdf[idx]) >> output
    #        cur += int((cdf[idx] - cur) / precision + 1) * precision
    #    }
    #}

    #printf("%-16.6f\t%-10.6f\n", maxNR, cdf[maxNR]) >> output


##### BELOW is old SAMPLING (JUNK) ####

#   printf("%-10.6f\t%-10.6f\n", lat[1], cdf[lat[1]]) > output

#   # data sampling
#   for (i = 1; i <= NSAMPLE-2; i++) {
#       idx = int((NR-2)/(NSAMPLE-2)) * i
#       printf("%-10.6f\t%-10.6f\n", lat[idx], cdf[lat[idx]]) >> output
#   }

#   printf("%-10.6f\t%-10.6f\n", lat[NR], cdf[lat[NR]]) >> output

}
