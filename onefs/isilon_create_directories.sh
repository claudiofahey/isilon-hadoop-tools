#!/bin/bash
###########################################################################
##  Script to create Hadoop directory structure on Isilon.
##  Must be run on Isilon system.
###########################################################################

if [ -z "$BASH_VERSION" ] ; then
   # probably using zsh...
   echo "Script not run from bash -- reinvoking under bash"
   bash "$0"
   exit $?
fi

declare -a ERRORLIST=()

DIST=""
FIXPERM="n"
ZONE="System"
CLUSTERNAME=""

#set -x

function banner() {
   echo "##################################################################################"
   echo "## $*"
   echo "##################################################################################"
}

function usage() {
   echo "$0 --dist <cdh|hwx|phd|phd3|bi> [--zone <ZONE>] [--fixperm] [--append-cluster-name <clustername>]"
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

function yesno() {
   [ -n "$1" ] && myPrompt=">>> $1 (y/n)? "
   [ -n "$1" ] || myPrompt=">>> Please enter yes/no: "
   read -rp "$myPrompt" yn
   [ "z${yn:0:1}" = "zy" -o "z${yn:0:1}" = "zY" ] && return 0
#   exit "DEBUG:  returning false from function yesno"
   return 1
}

function makedir() {
   if [ "z$1" == "z" ] ; then
      echo "ERROR -- function makedir needs directory as an argument"
   else
      mkdir -p $1
   fi
}

function fixperm() {
   if [ "z$1" == "z" ] ; then
      echo "ERROR -- function fixperm needs directory owner group perm as an argument"
   else
      uid=$(getUserUid $2)
      gid=$(getGroupGid $3)
      chown $uid $1
      chown :$gid $1
      chmod $4 $1

      #isi_run -z $ZONEIDchown $2 $1
      #isi_run -z $ZONEID chown :$3 $1
      #isi_run -z $ZONEID chmod $4 $1
   fi
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

function getAccessZoneId() {
    local zoneid
    zoneid=$(isi zone zones view $1 | grep "Zone ID:" | cut -f2 -d :)
    echo $zoneid
}

#Params: Username
function getUserUid() {
    local uid
    uid=$(isi auth users view --zone $ZONE $1$CLUSTERNAME | grep "  UID" | cut -f2 -d :)
    echo $uid
}

#Params: GroupName
function getGroupGid() {
    local gid
    gid=$(isi auth groups view --zone $ZONE $1$CLUSTERNAME | grep "  GID:" | cut -f2 -d :)
    echo $gid
}


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
      "--zone")
             shift
             ZONE="$1"
             echo "Info: will use users in zone:  $ZONE"
             ;;
      "--fixperm")
             echo "Info: will fix permissions and owners on existing directories"
             FIXPERM="y"
             ;;
      "--append-cluster-name")
             shift
             CLUSTERNAME="-$1"
             echo "Info: will add clustername to end of usernames: $CLUSTERNAME"
             ;;
      *)     echo "ERROR -- unknown arg $1"
             usage
             ;;
    esac
    shift;
done

declare -a dirList

case "$DIST" in
    "cdh")
        # Format is: dirname#perm#owner#group
        dirList=(\
            "/#755#hdfs#hadoop" \
            "/hbase#755#hbase#hbase" \
            "/solr#775#solr#solr" \
            "/tmp#1777#hdfs#supergroup" \
            "/tmp/logs#1777#mapred#hadoop" \
            "/tmp/hive#777#hive#supergroup" \
            "/user#755#hdfs#supergroup" \
            "/user/history#777#mapred#hadoop" \
            "/user/hive#775#hive#hive" \
            "/user/hive/warehouse#1777#hive#hive" \
            "/user/hue#755#hue#hue" \
            "/user/hue/.cloudera_manager_hive_metastore_canary#777#hue#hue" \
            "/user/impala#775#impala#impala" \
            "/user/oozie#775#oozie#oozie" \
            "/user/flume#775#flume#flume" \
            "/user/spark#751#spark#spark" \
            "/user/spark/applicationHistory#1777#spark#spark" \
            "/user/sqoop2#775#sqoop2#sqoop" \
            "/solr#775#solr#solr" \
        )
        ;;
    "hwx")
        # Format is: dirname#perm#owner#group
        dirList=(\
            "/#755#hdfs#hadoop" \
            "/app-logs#777#yarn#hadoop#" \
            "/app-logs/ambari-qa#770#ambari-qa#hadoop#" \
            "/app-logs/ambari-qa/logs#770#ambari-qa#hadoop#" \
            "/tmp#1777#hdfs#hdfs" \
            "/apps#755#hdfs#hadoop#" \
            "/apps/falcon#777#falcon#hdfs#" \
            "/apps/accumulo/#750#accumulo#hadoop#" \
            "/apps/hbase#755#hdfs#hadoop" \
            "/apps/hbase/data#775#hbase#hadoop" \
            "/apps/hbase/staging#711#hbase#hadoop" \
            "/apps/hive#755#hdfs#hdfs" \
            "/apps/hive/warehouse#777#hive#hdfs" \
            "/apps/tez#755#tez#hdfs" \
            "/apps/webhcat#755#hcat#hdfs" \
            "/mapred#755#mapred#hadoop" \
            "/mapred/system#755#mapred#hadoop" \
            "/user#755#hdfs#hdfs" \
            "/user/ambari-qa#770#ambari-qa#hdfs" \
            "/user/hcat#755#hcat#hdfs" \
            "/user/hdfs#755#hdfs#hdfs" \
            "/user/hive#700#hive#hdfs" \
            "/user/hue#755#hue#hue" \
            "/user/oozie#775#oozie#hdfs" \
            "/user/yarn#755#yarn#hdfs" \
            "/system/yarn/node-labels#700#yarn#hadoop" \
        )
        ;;
    "phd")
        # Format is: dirname#perm#owner#group
        dirList=(\
            "/#755#hdfs#hadoop" \
            "/apps#755#hdfs#hadoop#" \
            "/apps/hbase#755#hdfs#hadoop" \
            "/apps/hbase/data#775#hbase#hadoop" \
            "/apps/hbase/staging#711#hbase#hadoop" \
            "/hawq_data#770#gpadmin#hadoop"
            "/hive#755#hdfs#hadoop" \
            "/hive/gphd#755#hdfs#hadoop" \
            "/hive/gphd/warehouse#1777#hive#hadoop" \
            "/mapred#755#mapred#hadoop" \
            "/mapred/system#700#mapred#hadoop" \
            "/tmp#777#hdfs#hadoop" \
            "/tmp/gphdtmp#777#hdfs#hadoop" \
            "/user#777#hdfs#hadoop" \
            "/user/history#777#mapred#hadoop" \
            "/user/history/done#777#mapred#hadoop" \
            "/user/history/done_intermediate#1777#mapred#hadoop" \
            "/yarn#755#hdfs#hadoop" \
            "/yarn/apps#777#mapred#hadoop" \
        )
        ;;
    "phd3")
        # Format is: dirname#perm#owner#group
        dirList=(\
            "/#755#hdfs#hadoop" \
            "/app-logs#777#yarn#hadoop#" \
            "/apps#755#hdfs#hadoop#" \
            "/apps/hbase#755#hdfs#hadoop" \
            "/apps/hbase/data#775#hbase#hadoop" \
            "/apps/hbase/staging#711#hbase#hadoop" \
            "/hawq_data#770#gpadmin#hadoop"
            "/hive#755#hdfs#hadoop" \
            "/hive/gphd#755#hdfs#hadoop" \
            "/hive/gphd/warehouse#1777#hive#hadoop" \
            "/mapred#755#mapred#hadoop" \
            "/mapred/system#700#mapred#hadoop" \
            "/mr-history#755#mapred#hadoop" \
            "/tmp#1777#hdfs#hdfs" \
            "/tmp/gphdtmp#777#hdfs#hadoop" \
            "/user#777#hdfs#hadoop" \
            "/user/ambari-qa#770#ambari-qa#hdfs" \
            "/user/gpadmin#700#gpadmin#gpadmin" \
            "/user/hbase#700#hbase#hbase" \
            "/user/hcat#755#hcat#hdfs" \
            "/user/history#777#mapred#hadoop" \
            "/user/history/done#777#mapred#hadoop" \
            "/user/history/done_intermediate#1777#mapred#hadoop" \
            "/user/hive#700#hive#hdfs" \
            "/user/hue#755#hue#hue" \
            "/user/mapred#700#mapred#mapred" \
            "/user/oozie#775#oozie#hdfs" \
            "/user/spark#755#spark#spark" \
            "/user/spark/applicationHistory#1777#spark#spark" \
            "/user/tez#700#tez#tez" \
            "/user/yarn#700#yarn#yarn" \
            "/user/zookeeper#700#zookeeper#zookeeper" \
            "/yarn#755#hdfs#hadoop" \
            "/yarn/apps#777#mapred#hadoop" \
        )
        ;;
    "bi")
        # Format is: dirname#perm#owner#group
        dirList=(\
            "/#755#hdfs#hadoop" \
            "/tmp#1777#hdfs#hadoop" \
            "/user#755#hdfs#hadoop" \
            "/iop#755#hdfs#hadoop" \
            "/apps#755#hdfs#hadoop" \
            "/app-logs#755#hdfs#hadoop" \
            "/mapred#755#hdfs#hadoop" \
            "/mr-history#755#hdfs#hadoop" \
            "/user/ambari-qa#770#ambari-qa#hadoop" \
            "/user/hcat#775#hcat#hadoop" \
            "/user/hive#775#hive#hadoop" \
            "/user/oozie#775#oozie#hadoop" \
            "/user/yarn#775#yarn#hadoop" \
            "/user/zookeeper#775#zookeeper#hadoop" \
            "/user/uiuser#775#uiuser#hadoop" \
            "/user/spark#775#spark#hadoop" \
            "/user/sqoop#775#sqoop#hadoop" \
            "/user/solr#775#solr#hadoop" \
            "/user/nagios#775#nagios#hadoop" \
            "/user/bigsheets#775#bigsheets#hadoop" \
            "/user/bigsql#775#bigsql#hadoop" \
            "/user/dsmadmin#775#dsmadmin#hadoop" \
            "/user/flume#775#flume#hadoop" \
            "/user/hbase#775#hbase#hadoop" \
            "/user/knox#775#knox#hadoop" \
            "/user/mapred#775#mapred#hadoop" \
            "/user/bigr#775#bigr#hadoop" \
            "/user/bighome#775#bighome#hadoop" \
            "/user/tauser#775#tauser#hadoop" \
        )
        ;;
    *)
        echo "ERROR -- Invalid Hadoop distribution"
        usage
        ;;
esac

ZONEID=$(getAccessZoneId $ZONE)
echo "Info: Access Zone ID is $ZONEID"

HDFSROOT=$(getHdfsRoot $ZONE)
echo "Info: HDFS root dir is $HDFSROOT"

if [ ! -d $HDFSROOT ] ; then
   fatal "HDFS root $HDFSROOT does not exist!"
fi

# MAIN

banner "Creates Hadoop directory structure on Isilon system HDFS."

prefix=0
# Cycle through directory entries comparing owner, group, perm
# Sample output from "ls -dl"  command below
# drwxrwxrwx    8 hdfs  hadoop  1024 Aug 26 03:01 /tmp

for direntry in ${dirList[*]}; do
   read -a specs <<<"$(echo $direntry | sed 's/#/ /g')"
   echo "DEBUG: specs dirname ${specs[0]}; perm ${specs[1]}; owner ${specs[2]}; group ${specs[3]}"
   ifspath=$HDFSROOT${specs[0]}
   # echo "DEBUG:  ifspath = $ifspath"

   #  Get info about directory
   if [ ! -d $ifspath ] ; then
      # echo "DEBUG:  making directory $ifspath"
      makedir $ifspath
      fixperm $ifspath ${specs[2]} ${specs[3]} ${specs[1]}
   elif [ "$FIXPERM" == "y" ] ; then
      # echo "DEBUG:  fixing directory perm $ifspath"
      fixperm $ifspath ${specs[2]} ${specs[3]} ${specs[1]}
   else
      warn "Directory $ifspath exists but no --fixperm not specified"
   fi

done

if [ "${#ERRORLIST[@]}" != "0" ] ; then
   echo "ERRORS FOUND:"
   i=0
   while [ $i -lt ${#ERRORLIST[@]} ]; do
      echo "ERROR:  ${ERRORLIST[$i]}"
      i=$(($i + 1))
   done
   fatal "ERRORS FOUND making Hadoop admin directory structure -- please fix before continuing"
   exit 1
else
   echo "SUCCESS -- Hadoop admin directory structure exists and has correct ownership and permissions"
fi

echo "Done!"
