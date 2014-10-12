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

#set -x

function banner() {
   echo "##################################################################################"
   echo "## $*"
   echo "##################################################################################"
}

function usage() {
   echo "$0 --dist <cdh|phd> [--zone <ZONE>] [--fixperm]"
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
      mkdir $1
   fi
}
   
function fixperm() {
   if [ "z$1" == "z" ] ; then
      echo "ERROR -- function fixperm needs directory owner group perm as an argument"
   else
      isi_run -z $ZONEID chown $2:$3 $1
      isi_run -z $ZONEID chmod $4 $1
   fi
}

function getHdfsRoot() {
    local hdfsroot
    hdfsroot=$(isi zone zones view $1 | grep "HDFS Root Directory:" | cut -f2 -d :)
    echo $hdfsroot
}
 
function getAccessZoneId() {
    local zoneid
    hdfsroot=$(isi zone zones view $1 | grep "Zone ID:" | cut -f2 -d :)
    echo $hdfsroot
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
      *)     echo "ERROR -- unknown arg $1"
             usage
             ;;
    esac
    shift;
done

declare -a dirList

case "$DIST" in
    "cdh")
        dirList=(\
            "755#hdfs#hadoop##" \
            "1777#hdfs#supergroup#/tmp" \
            "755#hdfs#supergroup#/user" \
            "755#hbase#hbase#/hbase" \
            "777#mapred#hadoop#/user/history" \
            "1777#mapred#hadoop#/tmp/logs" \
            "775#oozie#oozie#/user/oozie" \
            "1s775#hive#hive#/user/hive" \
            "1777#hive#hive#/user/hive/warehouse" \
            "775#solr#solr#/solr" \
            "775#sqoop2#sqoop#/user/sqoop2" \
            "751#spark#spark#/user/spark" \
            "1777#spark#spark#/user/spark/applicationHistory" \
            "775#impala#impala#/user/impala" \
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
   # echo "DEBUG: specs dirname ${specs[3]}; owner ${specs[1]}; group ${specs[2]}; perm ${specs[0]}"
   ifspath=$HDFSROOT${specs[3]}
   # echo "DEBUG:  ifspath = $ifspath"

   #  Get info about directory
   if [ ! -d $ifspath ] ; then
      # echo "DEBUG:  making directory $ifspath"
      makedir $ifspath
      fixperm $ifspath ${specs[1]} ${specs[2]} ${specs[0]}
   elif [ "$FIXPERM" == "y" ] ; then
      # echo "DEBUG:  fixing directory perm $ifspath"
      fixperm $ifspath ${specs[1]} ${specs[2]} ${specs[0]}
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

