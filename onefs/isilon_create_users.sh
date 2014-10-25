#!/bin/bash
###########################################################################
##  Script to create Hadoop users on Isilon.
##  Must be run on Isilon system as root.
###########################################################################

if [ -z "$BASH_VERSION" ] ; then
   # probably using zsh...
   echo "Script not run from bash -- reinvoking under bash"
   bash "$0"
   exit $?
fi

declare -a ERRORLIST=()

DIST=""
STARTUID=1000
STARTGID=1000
ZONE="System"

#set -x

function banner() {
   echo "##################################################################################"
   echo "## $*"
   echo "##################################################################################"
}

function usage() {
   echo "$0 --dist <cdh|hwx|phd> --startgid <GID>] [--startuid <UID>] [--zone <ZONE>]"
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
    hdfsroot=$(isi zone zones view $1 | grep "HDFS Root Directory:" | cut -f2 -d :)
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
      "--dist")
             shift
             DIST="$1"
             echo "Info: Hadoop distribution:  $DIST"
             ;;
      "--startuid")
             shift
             STARTUID="$1"
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
      *)     
             echo "ERROR -- unknown arg $1"
             usage
             ;;
    esac
    shift;
done

case "$DIST" in
    "cdh")
        SUPER_USERS="hdfs mapred yarn"
        SUPER_GROUPS="hadoop supergroup"
        REQUIRED_USERS="$SUPER_USERS flume hbase hive hue impala oozie sample solr spark sqoop2"
        REQUIRED_GROUPS="$REQUIRED_USERS $SUPER_GROUPS sqoop"
        ;;
    "hwx")
        # See http://docs.hortonworks.com/HDPDocuments/Ambari-1.6.0.0/bk_ambari_reference/content/Defining-service-users-groups-2x.html
        SUPER_USERS="hdfs mapred yarn hbase storm falcon"
        SUPER_GROUPS="hadoop"
        REQUIRED_USERS="$SUPER_USERS tez hive hcat oozie zookeeper ambari-qa"
        REQUIRED_GROUPS="$REQUIRED_USERS $SUPER_GROUPS"
        ;;
    "phd")
        SUPER_USERS="hdfs mapred hbase gpadmin hive yarn"
        SUPER_GROUPS="hadoop"
        REQUIRED_USERS="$SUPER_USERS"
        REQUIRED_GROUPS="$REQUIRED_USERS $SUPER_GROUPS"
        ;;
    *)
        echo "ERROR -- Invalid Hadoop distribution"
        usage
        ;;
esac

HDFSROOT=$(getHdfsRoot $ZONE)
echo "Info: HDFS root:  $HDFSROOT"

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
       isi auth users create $user --uid $uid --primary-group $user --zone $ZONE --provider local --home-directory $HDFSROOT/user/$user
       [ $? -ne 0 ] && addError "Could not create user $user with uid $uid in zone $ZONE"
    fi
    uid=$(( $uid + 1 ))
done

for user in $SUPER_USERS; do
    for group in $SUPER_GROUPS; do
       isi auth groups modify $group --add-user $user --zone $ZONE
       [ $? -ne 0 ] && addError "Could not add user $user to $group group in zone $ZONE"
       done
done

# Special cases
case "$DIST" in
    "cdh")
        isi auth groups modify sqoop --add-user sqoop2 --zone $ZONE
        [ $? -ne 0 ] && addError "Could not add user sqoop2 to sqoop group in zone $ZONE"
        ;;
esac

### Deliver Results
if [ "${#ERRORLIST[@]}" != "0" ] ; then
   echo "ERRORS FOUND:"
   i=0
   while [ $i -lt ${#ERRORLIST[@]} ]; do
      echo "*  ERROR:  ${ERRORLIST[$i]}"
      i=$(( $i + 1 ))
   done
   fatal "ERRORS FOUND making Hadoop users in zone $ZONE -- please fix before continuing"
   exit 1
else
   echo "SUCCESS -- Hadoop users created successfully!"
fi

echo "Done!"

