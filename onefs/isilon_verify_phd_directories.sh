#!/bin/bash
###########################################################################
##  Script to verify PHD directory structure on Isilon.
##  Must be run on gphdmgr master host as it queries the gphdmgr database
###########################################################################
HAS_ERROR=0
CLIENT=smdw        # hard-coded default -- assume actual client passed as parameter
declare -a ERRORLIST=()

#set -x

function banner() {
   echo "##################################################################################"
   echo "## $*"
   echo "##################################################################################"
}

function fatal() {
   echo "FATAL:  $*"
   exit 1
}

function warn() {
   echo "ERROR:  $*"
   ERRORLIST[${#ERRORLIST[@]}]="$*"
}

function usage() {
   echo "Usage:  $0 [--hive] [--hbase] [--hawq] [--client CLIENTNODENAME]"
   exit 1
}

# Per Mahesh Kumar Vsanthu, Aug 26, 2014, these are the dirs we're supposed to have
# Dirlist is an array, hash-separated.  Each elemcnt is permissions#owner:group#dirname
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
"755#mapred#hadoop#/yarn/apps")

hbaseDirs=("755#hdfs#hadoop#/apps" \
"755#hdfs#hadoop#/apps/hbase" \
"775#hbase#hadoop#/apps/hbase/data" \
"711#hbase#hadoop#/apps/hbase/staging")

hiveDirs=("#755#hdfs#hadoop#/hive#" \
"755#hdfs#hadoop#/hive/gphd#" \
"1777#hive#hadoop#/hive/gphd/warehouse#")

hawqDirs=("#770#gpadmin#hadoop#/hawq_data#")
installHawq=1

# Parse Command-Line Args       
# Allow user to specify what functions to check 
while [ "z$1" != "z" ] ; do
    # echo "DEBUG:  Arg loop processing arg $1"
    case "$1" in

      "--hbase") 
             dirList=("${dirList[@]}" "${hbaseDirs[@]}")
             echo "Info: Including hbase directories."
             ;;
      "--hive")   
             dirList=("${dirList[@]}" "${hiveDirs[@]}")
             echo "Info: Including hive directories."
             ;;
      "--hawq")   
             dirList=("${dirList[@]}" "${hawqDirs[@]}")
             echo "Info: Including hawq directories."
             installHawq=0
             ;;
      "--all")   
             dirList=("${dirList[@]}" "${hiveDirs[@]}" "${hbaseDirs[@]}" "${hawqDirs[@]}")
             echo "Info: Including hbase, hive and hawq directories."
             installHawq=0
             ;;
      "--client")
             shift
             CLIENT=$1
             echo "Info: Client node:  $CLIENT"
             ;;
      *)     echo "ERROR -- unknown arg $arg"
             usage
             ;;
      "--help")  usage
             ;;
    esac
    shift
done


# MAIN

banner "Verifies PHD directory structure on Isilon system HDFS."

prefix=0
# Cycle through directory entries comparing owner, group, perm
# Sample output from hadoop fs -ls command below
# drwxr-xr-x   - mapred hadoop         24 2014-08-07 08:34 /mapred

for direntry in ${dirList[*]}; do
   prefix="0"
   read -a specs <<<"$(echo $direntry | sed 's/#/ /g')"
#   echo "DEBUG: specs dirname ${specs[3]}; owner ${specs[1]}; group ${specs[2]}; perm ${specs[0]}"
   echo "INFO: testing ${specs[3]}"

   #  Get info from hadoop fs -ls about directory
   read -a actual <<<"$(ssh $CLIENT 'sudo -u '${specs[1]}' hadoop fs -ls -d '${specs[3]}' | grep -v Found')"
   if [ ${#actual} -eq 0 ] ; then
      warn "Could not find directory ${specs[3]}"
      HAS_ERROR=1
      continue
   fi

   # Test Owner
   if [ "${specs[1]}" != "${actual[2]}" ] ; then 
      warn "Owner mismatch; directory ${specs[3]} should be ${specs[1]} but is ${actual[2]}"
      HAS_ERROR=1
      continue
   fi

   # Test Group
   if [ "${specs[2]}" != "${actual[3]}" ] ; then 
      warn "Group mismatch; directory ${specs[3]} should be ${specs[2]} but is ${actual[3]}"
      HAS_ERROR=1
      continue
   fi

   # Test Permissions -- first have to convert rwxrwxrwx to octal
   # echo "DEBUG:  rwxperm for directory ${specs[3]} is ${actual[0]}"
   binperm=$(echo ${actual[0]} | sed -e 's/^.//' -e 's/-/0/g' -e 's/[rwx]/1/g')
   # echo "DEBUG:  binperm for directory ${specs[3]} is $binperm"
   if [ $(echo $binperm | grep -i "t") ] ; then
      # found sticky bit
      prefix="1"
      binperm=$(echo $binperm | sed -e 's/t/1/g' -e 's/T/0/g')
   fi
   octperm=$(echo "obase=8; ibase=2; $prefix$binperm" | bc)

   # Now test the actual permissions
   if [ "$octperm" != "${specs[0]}" ] ; then
      warn "permissions mismatch directory ${specs[3]} should be ${specs[0]} but is $octperm"
      HAS_ERROR=1
   fi
   # echo "DEBUG: actual dirname ${actual[7]}; owner ${actual[2]}; group ${actual[3]}; perm $octperm"
done

# Negative test for previous hawq install
if [ $installHawq -eq 0 ] ; then
   for direntry in ${hawqDirs[*]}; do
      read -a specs <<<"$(echo $direntry | sed 's/#/ /g')"
      #  Already tested for /hawq_data, now look for existing subdirs
      echo "INFO:  looking for existing hawq install under $direntry"
      ssh $CLIENT 'sudo -u gpadmin hadoop fs -ls -d '${specs[3]}'/gpseg\* > /dev/null 2>&1'
      if [ "$?" -eq "0" ]; then
         warn "/hawq_data has subdirectories from previous hawq install; hawq initialize will fail"
         HAS_ERROR=1
      fi
   done
fi

echo

if [ "$HAS_ERROR" != "0" ] ; then
   echo "ERRORS FOUND:"
   i=0
   while [ $i -lt ${#ERRORLIST[@]} ]; do
      echo "*  ERROR:  ${ERRORLIST[$i]}"
      i=$(($i + 1))
   done
   fatal "ERRORS FOUND in PHD admin directory structure -- please fix before continuing"
   exit 1
else 
   echo "SUCCESS -- PHD admin directory structure exists and has correct ownership and permissions"
fi

echo "Done!"
