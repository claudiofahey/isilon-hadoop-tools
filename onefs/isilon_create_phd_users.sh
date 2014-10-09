#!/bin/bash
###########################################################################
##  Script to create  PHD users on Isilon.
##  Must be run on Isilon system as root.  Input is the hdfs root directory.
###########################################################################
if [ -z "$BASH_VERSION" ] ; then
   # probably using zsh...
   echo "Script not run from bash -- reinvoking under bash"
   bash "$0"
   exit $?
fi

declare -a ERRORLIST=()
REQUIRED_USERS="hdfs mapred hbase gpadmin hive yarn"
REQUIRED_GROUPS="$REQUIRED_USERS hadoop"
STARTUID=501
STARTGID=500
ZONE="System"

#set -x

function banner() {
   echo "##################################################################################"
   echo "## $*"
   echo "##################################################################################"
}

function usage() {
   echo "$0 [--startgid <GID>] [--startuid <UID>] [--zone <ZONE>]"
   echo "   defaults:  startgid=500, startuid=500, zone=System"
   exit 1
}

function fatal() {
   echo "FATAL:  $*"
   exit 1
}

function warn() {
   echo "ERROR:  $*"
   ERRORLIST[${#ERRORLIST[@]}]="$*"
}

function addError() {
   ERRORLIST+=("$*")
}

function yesno() {
   [ -n "$1" ] && myPrompt=">>> $1 (y/n)? "
   [ -n "$1" ] || myPrompt=">>> Please enter yes/no: "
   read -rp "$myPrompt" yn
   [ "z${yn:0:1}" = "zy" -o "z${yn:0:1}" = "zY" ] && return 0
#   exit "DEBUG:  returning false from function yesno"
   return 1
}

function uidInUse() {
   isi auth users view --uid $1 --zone $2 > /dev/null 2>&1
}

function userExists() {
   isi auth users view $1 --zone $2 > /dev/null 2>&1
}

function groupExists() {
   isi auth groups view $1 --zone $2 > /dev/null 2>&1
}

function gidInUse() {
   isi auth groups view --gid $1 --zone $2 > /dev/null 2>&1
}

function getUidFromUser() {
   local uid
   uid=$(isi auth users view $1 --zone $2 | awk '/^ *UID:/ {print $2}')
   echo $uid
}

function getUserFromUid() {
   local user
   user=$(isi auth users view --uid $1 --zone $2 | head -1 | awk '/^ *Name:/ {print $2}')
   echo $user
}

function getGidFromGroup() {
   local gid
   gid=$(isi auth groups view $1 --zone $2 | awk '/^ *GID:/ {print $2}')
   echo $gid
}

function getGroupFromGid() {
   local group
   group=$(isi auth groups view --gid $1 --zone $2 | head -1 | awk '/^ *Name:/ {print $2}')
   echo $group
}

function getHdfsRoot() {
    local hdfsroot
    hdfsroot=$(isi zone zones view $1 | grep "HDFS Root Directory" | cut -f2 -d :)
    echo $hdfsroot
}

### MAIN   main()

if [ "`uname`" != "Isilon OneFS" ]; then
   fatal "Script must be run on Isilon cluster as root."
fi

if [ "$USER" != "root" ] ; then
   fatal "Script must be run as root user."
fi

# Parse Command-Line Args
# Allow user to specify what functions to check
while [ "z$1" != "z" ] ; do
    # echo "DEBUG:  Arg loop processing arg $1"
    case "$1" in
      "--startuid")
             shift
             STARTUID=$1
             echo "Info: users will start at UID $STARTUID"
             ;;
      "--startgid")
             shift
             STARTGID="$1"
             echo "Info: groups will start at GID $STARTGID"
             ;;
      "--zone")
             shift
             ZONE="$1"
             echo "Info: will put users in zone:  $ZONE"
             ;;
      *)     echo "ERROR -- unknown arg $1"
             usage
             ;;
    esac
    shift;
done

hdfsroot=$(getHdfsRoot $ZONE)
echo "Info: HDFS root:  $hdfsroot"

# set -x
gid=$STARTGID
for group in $REQUIRED_GROUPS; do
    # echo "DEBUG:  GID=$gid"
    if groupExists $group $ZONE ; then 
       gid=$(getGidFromGroup $group $ZONE)
       addError "Group $group already exists at gid $gid in zone $ZONE"
    elif gidInUse $gid $ZONE ; then
       group=$(getGroupFromGid $gid $ZONE)
       addError "GID $gid already in use by group $group in zone $ZONE"
    else
       isi auth groups create $group --gid $gid --zone $ZONE
       [ $? -ne 0 ] && addError "Could not create group $group with gid $gid in zone $ZONE"
    fi
    gid=$(( $gid + 1 ))
done
# set +x

uid=$STARTUID
for user in $REQUIRED_USERS; do
    # echo "DEBUG:  UID=$uid"
    if userExists $user $ZONE ; then 
       uid=$(getUidFromUser $user $ZONE)
       addError "User $user already exists at uid $uid in zone $ZONE"
    elif uidInUse $uid $ZONE ; then
       user=$(getUserFromUid $uid $ZONE)
       addError "UID $uid already in use by user $user in zone $ZONE"
    else
       isi auth users create $user --uid $uid --primary-group $user --zone $ZONE --provider local --home-directory $hdfsroot/user/$user
       [ $? -ne 0 ] && addError "Could not create user $user with uid $uid in zone $ZONE"
       isi auth groups modify hadoop --add-user $user --zone $ZONE
       [ $? -ne 0 ] && addError "Could not add user $user to hadoop group in zone $ZONE"
    fi
    uid=$(( $uid + 1 ))
done

### Deliver Results
if [ "${#ERRORLIST[@]}" != "0" ] ; then
   echo "ERRORS FOUND:"
   i=0
   while [ $i -lt ${#ERRORLIST[@]} ]; do
      echo "*  ERROR:  ${ERRORLIST[$i]}"
      i=$(( $i + 1 ))
   done
   fatal "ERRORS FOUND making PHD users in zone $ZONE -- please fix before continuing"
   exit 1
else
   echo "SUCCESS -- PHD users created successfully!"
fi

echo "Done!"

