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
CLUSTER_NAME=""

#set -x

function banner() {
   echo "##################################################################################"
   echo "## $*"
   echo "##################################################################################"
}

function usage() {
   echo "$0 --dist <cdh|hwx|bi> [--startgid <GID>] [--startuid <UID>] [--zone <ZONE>] [--append-cluster-name <clustername>]"
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
#   exit ":  returning false from function yesno"
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
    #Check for Version to process correct syntax - isirad
    if [ "`isi version|cut -c 15`" -lt 8 ]; then
       hdfsroot=$(isi zone zones view $1 | grep "HDFS Root Directory:" | cut -f2 -d :)
    else
       hdfsroot=$(isi hdfs settings view --zone=$1 | grep "Root Directory:" | cut -f2 -d :)
    fi
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
      "--append-cluster-name")
             shift
             CLUSTER_NAME="-$1"
             echo "Info: will add clustername to end of usernames: $CLUSTER_NAME"
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
        REQUIRED_USERS="$SUPER_USERS flume hbase hive hue impala oozie sample solr spark sqoop2 anonymous nothdfs cmjobuser systest"
        REQUIRED_GROUPS="$REQUIRED_USERS $SUPER_GROUPS sqoop"
        ;;
    "hwx")
        SUPER_USERS="hdfs mapred yarn hbase storm falcon tracer"
        SUPER_GROUPS="hadoop"
        REQUIRED_USERS="$SUPER_USERS tez hive hcat oozie zookeeper ambari-qa flume hue accumulo hadoopqa sqoop anonymous spark mahout ranger kms atlas ams kafka"
        REQUIRED_GROUPS="$REQUIRED_USERS $SUPER_GROUPS"
        ;;
    "bi")
        SUPER_USERS="hdfs mapred hbase knox uiuser dsmadmin bigsheets ambari-qa rrdcached hive yarn hcat bigsql tauser bigr flume nagios solr spark sqoop zookeeper oozie bighome"
        SUPER_GROUPS="hadoop"
        REQUIRED_USERS="$SUPER_USERS anonymous ams"
        REQUIRED_GROUPS="$REQUIRED_USERS $SUPER_GROUPS"
        ;;
    *)
    echo "ERROR -- Invalid Hadoop distribution"
        usage
        ;;
esac

HDFSROOT=$(getHdfsRoot $ZONE)
echo "Info: HDFS root:  $HDFSROOT"
passwdfile="$ZONE.passwd"
echo "Info: passwd file: $passwdfile"
echo "# use this file to add to the passwd file of your clients" | cat > $passwdfile
grpfile="$ZONE.group"
echo "Info: group file: $grpfile"
echo "# use this file to add to the group file of your clients" | cat > $grpfile

# set -x
gid=$STARTGID
for group in $REQUIRED_GROUPS; do
    # echo "DEBUG:  GID=$gid"
    group="$group$CLUSTER_NAME"
    if groupExists $group $ZONE ; then
       gid=$(getGidFromGroup $group $ZONE)
       addError "Group $group already exists at gid $gid in zone $ZONE"
    elif gidInUse $gid $ZONE ; then
       group=$(getGroupFromGid $gid $ZONE)
       addError "GID $gid already in use by group $group in zone $ZONE"
    else
       isi auth groups create $group --gid $gid --zone $ZONE
       [ $? -ne 0 ] && addError "Could not create group $group with gid $gid in zone $ZONE"
       echo "$group:x:$gid" | cat >> $grpfile
       [ $? -ne 0 ] && addError "Could not create entry in group file stub $grpfile for $group with gid $gid"
    fi
    gid=$(( $gid + 1 ))
done
# set +x

uid=$STARTUID
for user in $REQUIRED_USERS; do
    # echo "DEBUG:  UID=$uid"
    user="$user$CLUSTER_NAME"
    if userExists $user $ZONE ; then
       uid=$(getUidFromUser $user $ZONE)
       addError "User $user already exists at uid $uid in zone $ZONE"
    elif uidInUse $uid $ZONE ; then
       user=$(getUserFromUid $uid $ZONE)
       addError "UID $uid already in use by user $user in zone $ZONE"
    else
       isi auth users create $user --uid $uid --primary-group $user --zone $ZONE --provider local --home-directory $HDFSROOT/user/$user
       [ $? -ne 0 ] && addError "Could not create user $user with uid $uid in zone $ZONE"
       gid=$(getGidFromGroup $user $ZONE)
       echo "$user:x:$uid:$gid:hadoop-svc-account:/home/$user:/bin/bash" | cat >> $passwdfile
       [ $? -ne 0 ] && addError "Could not create entry in passwd file stub $passwdfile for $user with uid $uid"
    fi
    uid=$(( $uid + 1 ))
done
# set +x

for group in $SUPER_GROUPS; do
    group="$group$CLUSTER_NAME"
    sprgrp=`grep $group $grpfile`
    [ $? -ne 0 ] && addError "Could not locate entry $group in group file stub $grpfile"
    for user in $SUPER_USERS; do
        user="$user$CLUSTER_NAME"
        isi auth groups modify $group --add-user $user --zone $ZONE
        [ $? -ne 0 ] && addError "Could not add user $user to $group group in zone $ZONE"
        sprgrp="$sprgrp,$user"
    done
    sed -i .bak /$group/d $grpfile
    echo $sprgrp | cat >> $grpfile
done
# set +x


# Special cases
case "$DIST" in
    "cdh")
        isi auth groups modify sqoop$CLUSTER_NAME --add-user sqoop2$CLUSTER_NAME --zone $ZONE
        [ $? -ne 0 ] && addError "Could not add user sqoop2$CLUSTER_NAME to sqoop$CLUSTER_NAME group in zone $ZONE"
        sqp=`grep sqoop2$CLUSTER_NAME $grpfile`
        sed -i .bak /$sqp/d $grpfile
        echo "$sqp,sqoop" | cat >> $grpfile
        [ $? -ne 0 ] && addError "Could not add user sqoop2$CLUSTER_NAME to sqoop$CLUSTER_NAME group in $grpfile"
        ;;
    "bi")
        isi auth groups modify users$CLUSTER_NAME --add-user hive$CLUSTER_NAME --zone $ZONE
        [ $? -ne 0 ] && addError "Could not add user hive$CLUSTER_NAME to users$CLUSTER_NAME group in zone $ZONE"
        isi auth groups modify hcat$CLUSTER_NAME --add-user hive$CLUSTER_NAME --zone $ZONE
        [ $? -ne 0 ] && addError "Could not add user hive$CLUSTER_NAME to hcat$CLUSTER_NAME group in zone $ZONE"
        hct=`grep hcat$CLUSTER_NAME: $grpfile`
        sed -i .bak /$hct/d $grpfile
        echo "$hct,hive$CLUSTER_NAME" | cat >> $grpfile
        [ $? -ne 0 ] && addError "Could not add user hive$CLUSTER_NAME to hcat$CLUSTER_NAME group in $grpfile"
        isi auth groups modify knox$CLUSTER_NAME --add-user kafka$CLUSTER_NAME --zone $ZONE
        [ $? -ne 0 ] && addError "Could not add user kafka$CLUSTER_NAME to knox$CLUSTER_NAME group in zone $ZONE"
        knx=`grep knox$CLUSTER_NAME: $grpfile`
        sed -i .bak /$knx/d $grpfile
        echo "$knx,kafka$CLUSTER_NAME" | cat >> $grpfile
        [ $? -ne 0 ] && addError "Could not add user kafka$CLUSTER_NAME to knox$CLUSTER_NAME group in $grpfile"
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
