#!/bin/bash
#####################################################################################
##
##  Script verifies that required users and groups exist on Isilon system, from DCA.
##  Selects a client node at random (hard-coded in this script), then uses ssh to 
##  create a /zzTestUsers directory with umask 000.  
##
##  After that, the script uses ssh and sudo to create a sample directory as each
##  user name.
##
##  Isilon hdfs root is owned by hdfs user, so we create zzTestUsers as hdfs.
#####################################################################################
# set -x
TEST_NOUSER="rmk"
HBASE_USERS="hbase"
HIVE_USERS="hive"
REQUIRED_USERS="hdfs gpadmin mapred yarn"
REQUIRED_GROUPS="hadoop"
CLIENT=smdw     # hard-coded default
BASEPATH="/zzTestUsers"
declare -a ERRORLIST

function usage() {
   echo "$0 [--hbase] [--hive] [--client CLIENTNODE]"
   exit 1
}

function addError() {
   ERRORLIST+=("$*")
}

function testHadoopInstalledOnClient() {
   ssh $CLIENT which hadoop > /dev/null 2>&1
}

# Check if user is part of REQUIRED_USERS
function inRequiredUsers() {
   exitCode=1
   for user in $REQUIRED_USERS; do
      [ "$user" == "$1" ] && exitCode=0
   done
   # echo "DEBUG:  inRequiredUsers exit is $exitCode"
   return $exitCode
}

function makeDir() {
   # pass $1 = directory, $2 = owner; returns 0 on success, 1 otherwise
   mkdir_cmd="sudo -u $2 hadoop fs -Dfs.permissions.umask-mode=000 -mkdir $1"
   ssh $CLIENT "$mkdir_cmd" > /dev/null 2>&1
}
   
function getDirOwner() {
   # pass $1 = directory; returns owner of the directory
   dirOwner=`ssh $CLIENT 'hadoop fs -ls -d ' $1 | grep -v Found | awk '{print $3}'`
   echo "$dirOwner"
}

function checkDirOwner() {
   # pass $1 = directory, $2 = desired owner
   dirOwner=`ssh $CLIENT 'hadoop fs -ls -d ' $1 | grep -v Found | awk '{print $3}'`
   [ "$dirOwner" == "$2" ]
}

function changeDirGroup() {
   # pass $1 = directory, $2 = user, $3 = desired group; returns 0 if could change group ownership
   cmd="sudo -u $2 hadoop fs -chgrp $3 $1"
   ssh $CLIENT "$cmd" > /dev/null 2>&1
}

function checkDirGroup() {
   # pass $1 = directory, $2 = desired group
   dirGroup=`ssh $CLIENT 'hadoop fs -ls -d ' $1 | grep -v Found | awk '{print $4}'`
   [ "$dirGroup" == "$2" ]
}

# Check if /tmp exists
function dirIsWriteable() {
   [ -z "$1" ] && return 1
   ssh $CLIENT 'hadoop fs -ls -d '$1 | grep -v Found | egrep "^d......rwx" >/dev/null 2>&1
   return $?
}


### MAIN   main()

# Parse Command-Line Options
while [ "z$1" != "z" ] ; do
    # echo "DEBUG:  Arg loop processing arg $1"
    case "$1" in
      "--hbase")
             REQUIRED_USERS=("${REQUIRED_USERS} ${HBASE_USERS}")
             echo "Info: Including hbase users."
             ;;
      "--hive")
             REQUIRED_USERS=("${REQUIRED_USERS} ${HIVE_USERS}")
             echo "Info: Including hive users."
             ;;
      "--all")
             REQUIRED_USERS=("${REQUIRED_USERS} ${HBASE_USERS} ${HIVE_USERS}")
             echo "Info: Including all users (base, hbase, hive, hawq)"
             ;;
      "--client")
             shift
             CLIENT=$1
             echo "Info: Client node:  $CLIENT"
             ;;
      *)     echo "ERROR -- unknown arg $1"
             usage
             ;;
    esac
    shift;
done

testHadoopInstalledOnClient || fatal "Hadoop command not found on client $CLIENT.  Is cluster installed?"

# Check ownership of HDFS root directory
hdfsOwner=$(getDirOwner /)
echo "DEBUG:  HDFS OWNER is $hdfsOwner"

# Verify 
if  ! (dirIsWriteable / || inRequiredUsers $hdfsOwner) ; then
   echo "WARNING:  HDFS root not writeable by any required users; looking for HDFS /tmp"
   if ! dirIsWriteable /tmp; then
      echo "FATAL:  Cannot write test files to check for Isilon users"
      exit 1
   else 
      BASEPATH="/tmp$BASEPATH"
      echo "/tmp exists and is writeable -- proceeding with basepath $BASEPATH"
   fi
fi

ssh $CLIENT "sudo -u $hdfsOwner hadoop fs -rm -r -skipTrash $BASEPATH > /dev/null 2>&1"
ssh $CLIENT "sudo -u $hdfsOwner hadoop fs -Dfs.permissions.umask-mode=000 -mkdir $BASEPATH"
if [ $? -ne 0 ] ; then
   echo "FATAL could not create basepath $BASEPATH on $CLIENT as user hdfs"
   exit 1
fi

for user in $REQUIRED_USERS; do
   echo "Checking user $user"
   dirpath="$BASEPATH/${user}_dir"
   if makeDir $dirpath $user ; then
     checkDirOwner $dirpath $user || addError "Directory $dirpath verified incorrectly"
     changeDirGroup $dirpath $user $user || addError "Group $user does not exist"
     changeDirGroup $dirpath $user hadoop || addError "$user is not part of hadoop group"
   else 
     addError "$user does not exist -- could not create directory $dirpath as $user"
   fi
done

if [ ${#ERRORLIST} -ne 0 ] ; then
   echo "ERRORS encountered.  Please work with Isilon admin to verify that users exist in this access zone."
   for (( i=0; i < ${#ERRORLIST[@]}; i++ )) ; do
      echo "*  ${ERRORLIST[$i]}"
   done
   exit 1
else
   # cleanup
   ssh $CLIENT "sudo -u $hdfsOwner hadoop fs -rm -r -skipTrash $BASEPATH > /dev/null 2>&1"
   echo "SUCCESS!  PHD users verified!"
fi
