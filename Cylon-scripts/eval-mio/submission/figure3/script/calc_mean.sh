#!/bin/bash
awk '
NR==1 {prev_cdf=$2; prev_lat=$1} 
NR>1 {
    prob_mass = $2 - prev_cdf
    mid_lat = (prev_lat + $1) / 2
    sum += mid_lat * prob_mass
    prev_cdf = $2
    prev_lat = $1
} 
END {print sum}' $1
