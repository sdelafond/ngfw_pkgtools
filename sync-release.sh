#! /bin/bash

usage() {
  echo "Usage: $0 [-s] [-w] -r <repository> -d <distribution> -v <version>"
  echo "-s : simulate"
  echo "-w : wipe out target before sync'ing"
  echo "-r : repository to use"
  echo "-d : distribution to sync"
  echo "-v : version (needs to be a full x.y.z)"
  exit 1
}

while getopts "wshr:d:v:" opt ; do
  case "$opt" in
    s) simulate=1 ;;
    w) WIPE_OUT_TARGET=1 ;;
    r) REPOSITORY=$OPTARG ;;
    d) DISTRIBUTION=$OPTARG ;;
    v) VERSION=$OPTARG ;;
    h) usage ;;
    \?) usage ;;
  esac
done
shift $(($OPTIND - 1))
if [ ! $# = 0 ] ; then
  usage
fi

[ -z "$REPOSITORY" -o -z "$DISTRIBUTION" - o -z "$VERSION" ] && usage && exit 1

pkgtools=`dirname $0`
. $pkgtools/release-constants.sh

changelog_file=$(mktemp "sync-$REPOSITORY-$FROM_DISTRIBUTION-to-$TO_DISTRIBUTION-$(date -Iminutes)-XXXXXXX.txt")
diffCommand="python3 $pkgtools/changelog.py --log-level info --version $VERSION --tag-type sync --create-tags"

# MAIN
copyRemotePkgtools

if [ -z "$simulate" ] ; then
#  $SSH_COMMAND /etc/init.d/untangle-gpg-agent start
  $diffCommand >| $changelog_file

  # wipe out target distribution first
  [ -n "$WIPE_OUT_TARGET" ] && remoteCommand ./remove-packages.sh -r ${REPOSITORY} -d ${DISTRIBUTION}

  date="$(date)"
  repreproRemote --noskipold update ${DISTRIBUTION} || exit 1

  # also remove source packages for premium non-free; this is really just a
  # safety measure now, as the update process itself is smarter and
  # knows not to pull sources for premium non-free.
#  $SSH_COMMAND ./remove-packages.sh -r ${REPOSITORY} -d ${DISTRIBUTION} -t dsc -c premium non-free

  repreproRemote export ${DISTRIBUTION} || exit 1

  if [ -n "$MANIFEST" ] ; then
    attachments="-a ${changelog_file}"

    mutt -F $MUTT_CONF_FILE $attachments -s "[Distro sync] $REPOSITORY: $(hostname)/$DISTRIBUTION pushed to updates.u.c/$DISTRIBUTION" -- $RECIPIENT <<EOF
Effective $(date) (started at $date).

Attached are the diff files for this push, generated by running
the following command prior to actually promoting:

  $diffCommand

--ReleaseMaster ($USER@$(hostname))

EOF
  fi

  /bin/rm -f ${changelog_file}
#  $SSH_COMMAND /etc/init.d/untangle-gpg-agent stop
else
  repreproRemote "checkupdate $DISTRIBUTION 2>&1 | grep upgraded | sort -u"
  remoteCommand ./remove-packages.sh -r ${REPOSITORY} -d ${DISTRIBUTION} -T dsc -C premium non-free -s
fi

# remove remote pkgtools
removeRemotePkgtools
