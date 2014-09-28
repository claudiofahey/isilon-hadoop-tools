#!/bin/bash
#
# Usage:
#  1. ssh to Isilon node as root
#  2. bash isilon_create_directories.sh /ifs/hadoop
#

#set -x

function die () {
   echo "FATAL: $1"
   exit 1
}

function isdigit () {
   [ $# -eq 1 ] || return 1;
   [[ $1 = *[^0-9]* ]] && return 1
   return 0
}

function isdigit () {     
   [ $# -eq 1 ] || return 1;      
   case $1 in
         *[0-9]*|"") return 0;;
         *) return 1;;     
   esac; 
}

function banner() {
   echo "*********************************************************************************"
   echo -n "**   "
   echo -e $1
   echo "*********************************************************************************"
}

function yesno() {
   [ -n "$1" ] && myPrompt=">>> $1 (y/n)? "
   [ -n "$1" ] || myPrompt=">>> Please enter yes/no: "
   read -rp "$myPrompt" yn
   [ "z${yn:0:1}" = "zy" -o "z${yn:0:1}" = "zY" ] && return 0
#   exit "DEBUG:  returning false from function yesno"
   return 1
}

function warn() {
   echo "WARNING:  $*"
}

function createDirectory() {
   # performs initial directory creation. since we need to create sub-dirs, 
   # start with permissions 777; later chmodDirectory will change to correct
   # expect passed-in variable to be dirLen#dirPath#user:group#perm
   local path=$basedir`echo $1 | cut -f2 -d#`
   local user=`echo $1 | cut -f3 -d# | cut -f1 -d:`
   local group=`echo $1 | cut -f3 -d# | cut -f2 -d:`
#   echo "DEBUG:  CREATE DIR $path PERM $perm OWNER $user:$group RUNAS USER $user"
   mkdir -p $path && chmod 777 $path && chown $user:$group $path || warn "Problem making $path"
}

function chmodDirectory() {
   # expect passed-in variable to be dirLen#dirPath#user:group#perm
   local path=$basedir`echo $1 | cut -f2 -d#`
   local user=`echo $1 | cut -f3 -d# | cut -f1 -d:`
   local perm=`echo $1 | cut -f4 -d#`
#   echo "DEBUG chmod directory $path to $perm"
   chmod $perm $path || warn "Could not chmod dir $path to $perm"
}

function find_dirLen() {
   # directory path passed in; returns number of directories in path
   local dirLen=`echo ${1//\// /} | wc -w`
#   echo -e "DEBUG:  find_dirLen of $1 = $dirLen\n"
   return $dirLen
}
   
function populate_dirList() {
   # expect $1 = dirname (key), $2 = owner:group, $3 = permissions
   # prepend directory path length
   find_dirLen $1
   local dirLen=$?
   dirList+=("$dirLen#$1#$2#$3")
#   echo -e "DEBUG:  populate dirList=$dirLen#$1#$2#$3"
}

# MAIN

banner "Creates directories on Isilon system HDFS."

basedir=$1
echo "This will create Hadoop directories in $basedir"

yesno "Continue? " || die "Exiting on user input"

# Declare the directory structure we want to create
# format /dirPath owner:group perm
declare -a dirList
dirList=()
populate_dirList /.	hdfs:hadoop	755
populate_dirList /apps	hdfs:hadoop	755
populate_dirList /apps/hbase	hdfs:hadoop	755
populate_dirList /apps/hbase/data	hbase:hadoop	775
populate_dirList /hive	hdfs:hadoop	755
populate_dirList /hive/gphd	hdfs:hadoop	755
populate_dirList /hive/gphd/warehouse	hive:hadoop	775
populate_dirList /mapred	mapred:hadoop	755
populate_dirList /mapred/system	mapred:hadoop	700
populate_dirList /tmp	hdfs:hadoop	777
populate_dirList /tmp/gphdtmp	hdfs:hadoop	777
populate_dirList /user	hdfs:hadoop	777
populate_dirList /user/history	mapred:hadoop	777
populate_dirList /user/history/done	mapred:hadoop	777
populate_dirList /var	yarn:hadoop	777
populate_dirList /var/log	yarn:hadoop	777
populate_dirList /var/log/hadoop-yarn	yarn:hadoop	777
populate_dirList /var/log/hadoop-yarn/apps	yarn:hadoop	1777
populate_dirList /yarn	hdfs:hadoop	755
populate_dirList /yarn/apps	mapred:hadoop	1777
populate_dirList /hawq_data gpadmin:hadoop 777

# Create directories in order of least depth to greatest
myTmpList=/tmp/mkIsiDirs_`date +%s`
rm -rf $myTmpList > /dev/null 2>&1
for i in ${dirList[*]}; do 
    echo -e "$i\n" >> $myTmpList
done

for i in `cat $myTmpList | sort -n`; do
    createDirectory $i
done

for i in `cat $myTmpList | sort -n -r`; do
    chmodDirectory $i
done

# Clean up temp file
rm -rf $myTmpList > /dev/null 2>&1
echo "Done!"

