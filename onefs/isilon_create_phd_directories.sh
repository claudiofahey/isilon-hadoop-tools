#!/bin/bash
###########################################################################
##  Script to create  PHD directory structure on Isilon.
##  Must be run on Isilon system.  Input is the hdfs root directory.
###########################################################################
FIXPERM="n"
declare -a ERRORLIST=()

#set -x

function banner() {
   echo "##################################################################################"
   echo "## $*"
   echo "##################################################################################"
}

function usage() {
   echo "$0 [--hbase] [--hive] [--hawq] --fixperm --hdfsroot <hdfs root dir>"
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
      chown $2:$3 $1
      chmod $4 $1
   fi
}
   

# Per Mahesh Kumar Vsanthu, Aug 26, 2014, these are the dirs we're supposed to have.
# The lists are arrays, hash-separated.  Each elemcnt is permissions#owner#group#dirname
# Each is relative to the hdfs root directory.
#  # tmp
#  drwxrwxrwx   - hdfs   hadoop          0 2014-08-25 16:13 /tmp
#  drwxrwxrwx   - hdfs   hadoop          0 2014-08-25 16:13 /tmp/gphdtmp
#  # Yarn
#  drwxr-xr-x   - mapred hadoop          0 2014-08-25 16:13 /mapred
#  drwx------   - mapred hadoop          0 2014-08-25 16:13 /mapred/system
#  drwxrwxrwx   - hdfs   hadoop          0 2014-08-25 16:13 /user
#  drwxrwxrwx   - mapred hadoop          0 2014-08-25 16:13 /user/history
#  drwxrwxrwx   - mapred hadoop          0 2014-08-25 16:13 /user/history/done
#  drwxrwxrwt   - mapred hadoop          0 2014-08-25 16:13 /user/history/done_intermediate
#  drwxr-xr-x   - hdfs   hadoop          0 2014-08-25 16:13 /yarn
#  drwxrwxrwx   - mapred hadoop          0 2014-08-25 16:13 /yarn/apps
#  # Hbase
#  drwxr-xr-x   - hdfs   hadoop          0 2014-08-25 16:12 /apps
#  drwxr-xr-x   - hdfs   hadoop          0 2014-08-25 16:12 /apps/hbase
#  drwxrwxr-x   - hbase  hadoop          0 2014-08-25 16:12 /apps/hbase/data
#  drwx--x--x   - hbase  hadoop          0 2014-08-25 16:12 /apps/hbase/staging
#  # Hive
#  drwxr-xr-x   - hdfs   hadoop          0 2014-08-25 16:13 /hive
#  drwxr-xr-x   - hdfs   hadoop          0 2014-08-25 16:13 /hive/gphd
#  drwxrwxrwt   - hive   hadoop          0 2014-08-25 16:13 /hive/gphd/warehouse

# Below, dirList is my core directories for MapReduce and temp. hbaseDirs is specific to hbase; hiveDirs to hive
declare -a dirList hbaseDirs hiveDirs

dirList=("777#hdfs#hadoop#/tmp" \
"777#hdfs#hadoop#/tmp/gphdtmp" \
"755#mapred#hadoop#/mapred" \
"700#mapred#hadoop#/mapred/system" \
"777#hdfs#hadoop#/user" \
"777#mapred#hadoop#/user/history" \
"777#mapred#hadoop#/user/history/done" \
"1777#mapred#hadoop#/user/history/done_intermediate" \
"755#hdfs#hadoop#/yarn" \
"777#mapred#hadoop#/yarn/apps")

hbaseDirs=("755#hdfs#hadoop#/apps" \
"755#hdfs#hadoop#/apps/hbase" \
"775#hbase#hadoop#/apps/hbase/data" \
"711#hbase#hadoop#/apps/hbase/staging")

hiveDirs=("755#hdfs#hadoop#/hive#" \
"755#hdfs#hadoop#/hive/gphd#" \
"1777#hive#hadoop#/hive/gphd/warehouse#")

hawqDirs=("770#gpadmin#hadoop#/hawq_data#")

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
      "--hbase") 
             echo "DEBUG: found arg --hbase"
             dirList=("${dirList[@]}" "${hbaseDirs[@]}")
             echo "Info: Including hbase directories."
             ;;
      "--hive")   
             echo "DEBUG: found arg --hive"
             dirList=("${dirList[@]}" "${hiveDirs[@]}")
             echo "Info: Including hive directories."
             ;;
      "--hawq")   
             echo "DEBUG: found arg --hawq"
             dirList=("${dirList[@]}" "${hawqDirs[@]}")
             echo "Info: Including hawq directories."
             ;;
      "--hdfsroot")
             shift
             HDFSROOT=$1
             echo "Info: HDFS root dir is $HDFSROOT"
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
 
if [ "z$HDFSROOT" == "z" ] ; then
   echo "You must specify an hdfs root directory"
   usage
fi

if [ ! -d $HDFSROOT ] ; then
   read -p "HDFS root directory ($HDFSROOT) does not exist.  Create it?  " yesno
   if [ ${yesno:0:1} == "y" -o ${yesno:0:1} == "Y" ] ; then
      mkdir $HDFSROOT
      if [ $? -ne 0 ] ; then
         fatal "Could not create HDFS root directory $HDFSROOT"
      fi
   else
      fatal "HDFS root $HDFSROOT does not exist and you said don't create it!"
   fi
fi
   

# MAIN

banner "Verifies PHD directory structure on Isilon system HDFS."

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
   fatal "ERRORS FOUND making PHD admin directory structure -- please fix before continuing"
   exit 1
else 
   echo "SUCCESS -- PHD admin directory structure exists and has correct ownership and permissions"
fi

echo "Done!"
