#! /bin/bash

usage() {
  echo "Usage: $0 [-s] [-w] -r <repository> <fromDistribution> <toDistribution>"
  echo "-s : simulate"
  echo "-w : wipe out <toDistribution> first"
  exit 1
}

while getopts "shwr:d:" opt ; do
  case "$opt" in
    s) simulate=1 && EXTRA_ARGS="-s" ;;
    r) REPOSITORY=$OPTARG ;;
    w) WIPE_OUT_TARGET=1 ;;
    h) usage ;;
    \?) usage ;;
  esac
done
shift $(($OPTIND - 1))
if [ ! $# = 2 ] ; then
  usage
fi

FROM_DISTRIBUTION=$1
TO_DISTRIBUTION=$2

[ -z "$REPOSITORY" -o -z "$FROM_DISTRIBUTION" -o -z "$TO_DISTRIBUTION" ] && usage && exit 1

pkgtools=`dirname $0`
tmp_base=/tmp/promotion-$REPOSITORY-$FROM_DISTRIBUTION-to-$TO_DISTRIBUTION-`date -Iminutes`
/bin/rm -f ${tmp_base}*
diffCommand="$pkgtools/apt-chroot-utils/compare-sources.py `hostname`,$REPOSITORY,$FROM_DISTRIBUTION `hostname`,$REPOSITORY,$TO_DISTRIBUTION $tmp_base"

. $pkgtools/release-constants.sh

##########
# MAIN

python $diffCommand

# wipe out target distribution first
[ -n "$WIPE_OUT_TARGET" ] && $pkgtools/remove-packages.sh $EXTRA_ARGS -r $REPOSITORY -d $TO_DISTRIBUTION

# actual promotion
$pkgtools/copy-packages.sh $EXTRA_ARGS -r $REPOSITORY $FROM_DISTRIBUTION $TO_DISTRIBUTION

# remove the sources for hades 
#$pkgtools/remove-packages.sh $EXTRA_ARGS -r $REPOSITORY -d $TO_DISTRIBUTION -c premium -t dsc

mutt -F /dev/null -s "[$REPOSITORY] $FROM_DISTRIBUTION promoted to $TO_DISTRIBUTION" -a ${tmp_base}.txt -a ${tmp_base}.csv tech-internal@untangle.com <<EOF
Effective `date`

Attached are the diff files for this promotion generated by running
the following command prior to actually promoting:

  $diffCommand

--ReleaseMaster ($USER@`hostname`)
EOF

/bin/rm -f ${tmp_base}*
