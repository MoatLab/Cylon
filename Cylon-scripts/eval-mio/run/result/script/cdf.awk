BEGIN {
    i = 0
    sum = 0
    minflag = 0
    maxflag = 0
}

{
    i++
    lat[i] = $1
    freq[$1] += 1
}

END {
    PROCINFO["sorted_in"] = "@ind_num_asc"

    for (idx in freq) {
        sum += freq[idx]
        cdf[idx] = sum
    }


    # calculate cdf() using freq/sum
    for (idx in freq) {
        cdf[idx] /= sum
        if ((minflag == 0) && cdf[idx] >= min) {
            minNR = idx
            minflag = 1
        }
        if ((maxflag == 0) && cdf[idx] >= max) {
            if (cdf[idx] == max)
                maxNR = idx
            else
                maxNR = idx - 1
            maxflag = 1
        }
    }

    cur = min

    for (idx in cdf) {
        if (cdf[idx] < cdf[minNR] || cdf[idx] > cdf[maxNR]) {
            continue
        } else if ((cdf[idx] >= cur) && (cdf[idx] < cur + precision)) {
            printf("%-16.6f\t%-10.6f\n", idx, cdf[idx]) >> output
            cur += precision
        } else if (cdf[idx] >= cur + precision) {
            printf("%-16.6f\t%-10.6f\n", idx, cdf[idx]) >> output
            cur += int((cdf[idx] - cur) / precision + 1) * precision
        }
    }

    # just in case we don't have "1.0" in the sampled output
    printf("%-16.6f\t%-10.6f\n", maxNR, cdf[maxNR]) >> output


##### BELOW is old SAMPLING (JUNK) ####

#   printf("%-10.6f\t%-10.6f\n", lat[1], cdf[lat[1]]) > output

#   # data sampling
#   for (i = 1; i <= NSAMPLE-2; i++) {
#       idx = int((NR-2)/(NSAMPLE-2)) * i
#       printf("%-10.6f\t%-10.6f\n", lat[idx], cdf[lat[idx]]) >> output
#   }

#   printf("%-10.6f\t%-10.6f\n", lat[NR], cdf[lat[NR]]) >> output

}
