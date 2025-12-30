#!/bin/bash
# Author: Huaicheng <huaicheng@cs.uchicago.edu>
# Usage: ./sample-cdf.sh <inputfile> <MIN> <MAX> <PRECISION> <outputfile>

SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
    TOPDIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
    SOURCE="$(readlink "$SOURCE")"
    [[ $SOURCE != /* ]] && SOURCE="$TOPDIR/$SOURCE"
done

TOPDIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )/.."
RAWDIR=$TOPDIR/raw
DATDIR=$TOPDIR/dat
SCRIPTDIR=$TOPDIR/script
PLOTDIR=$TOPDIR/plot
EPSDIR=$TOPDIR/eps
STATDIR=$TOPDIR/stat

######################################################################

if [[ $# -ne 5 ]]; then
    echo "Usage: $0 <inputfile> <MIN> <MAX> <PRECISION> <outputfile>"
    echo "BEAWARE: inputfile should be already sorted"
    exit
fi

input=$1
MIN=$2
MAX=$3
PRECISION=$4
output=$5

cat /dev/null > $output
gawk -v min=$MIN -v max=$MAX -v precision=$PRECISION -v output=$output -f $SCRIPTDIR/cdf.awk $input

