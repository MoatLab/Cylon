#!/bin/bash
# Author: Huaicheng <huaicheng@cs.uchicago.edu>
# Use: convert raw log file (e.g. fio lat log) for cdf plotting
#
# raw -> get latency data column -> sort -> CDF(x, y) -> sampling -> dat
# |-----------> this script <---------| call |----> sample-cdf.sh <-----|

set -e # Exit on Error


SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
    TOPDIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
    SOURCE="$(readlink "$SOURCE")"
    [[ $SOURCE != /* ]] && SOURCE="$TOPDIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done

TOPDIR="$( cd -P "$( dirname "$SOURCE" )/" && pwd )/.."
RAWDIR=$TOPDIR/raw
DATDIR=$TOPDIR/dat
SCRIPTDIR=$TOPDIR/script
PLOTDIR=$TOPDIR/plot
EPSDIR=$TOPDIR/eps
STATDIR=$TOPDIR/stat

################################################################################

if [[ $# -ne 5 ]]; then
    echo "Usage:"
    printf "\t./raw2dat-lat-cdf.sh TYPE dtrs MIN MAX PRECISION\n"
    printf "HERE, dtrs is sub-directory under raw/\n"
    exit
fi

TYPE=$1
TARGET=$2
MIN=$3
MAX=$4
PRECISION=$5

tgtrawdir=$RAWDIR/$TARGET

if [[ ! -d "$tgtrawdir" ]]; then
    echo "Cannot find raw files, there is no $TARGET under $RAWDIR, exiting ..."
    exit
fi

tgtdatdir=$DATDIR/$TARGET
# be careful with the directories ...
if [[ ! -d "$tgtdatdir" ]]; then
    mkdir -p $tgtdatdir
fi

# $1: input raw file, $2: output dat file
function raw2dat_lat_cdf()
{
    input=$1
    tmp=${input/log/tmp}
    
    #gawk '{print $2}' $1 | sort -n -o $tmp
    #cat $1 | sort -n -o $tmp
    gawk -F"," '{print $2}' $1 | sort -n -o $tmp
    # use the following line when you don't want to include 0-1us latency in your CDF graph
    #gawk -F"," '{if ($2 >= 40) print $2}' $1 | sort -n -o $tmp
    # CDF(x, y), sampling
    $SCRIPTDIR/sample-cdf-lat.sh $tmp $MIN $MAX $PRECISION $2
}

function raw2dat_lat_time()
{
    #gawk '{
    #    if (NR == 1) start_time = $1
    #    relative_time = ($1 - start_time) / 1000  # Convert to seconds
    #    print relative_time, $2
    #}' $1 > $2
    #gawk '{print $1, $2}' $1 > $2
    gawk -F"," '{print $1, $2}' $1 > $2
}

function raw2dat_iops_time()
{
    gawk -F"," '{print $1, $2}' $1 > $2
}



################################################################################
#################                 M A I N             ##########################
################################################################################

case $TYPE in
    "lat-cdf")
        raw2dat_handler=raw2dat_lat_cdf
        ;;
    "lat-time")
        raw2dat_handler=raw2dat_lat_time
        ;;
    "iops-time")
        raw2dat_handler=raw2dat_iops_time
        ;;
    *)
        echo "Unknown TYPE, exiting ..."
        exit
        ;;
esac

cd $tgtrawdir

for rawfile in *.log; do
    fname=${rawfile%.*}
    #if [[ ! -e ${fname}.tmp ]]; then
    #gawk -F"," '{print $2}' $rawfile | sort -n -o ${fname}.tmp
    ${raw2dat_handler} $rawfile ${fname}.dat
    mv ${fname}.dat $tgtdatdir
    #fi

done


echo "==== raw2dat done ===="

