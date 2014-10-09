#!/bin/bash

gid_base=$1
uid_base=$2

gid=$gid_base
for group in hdfs mapred hbase gpadmin hive yarn hadoop; do
    groupadd --gid $gid $group
    gid=$(($gid + 1))
done

uid=$uid_base
for user in hdfs mapred hbase gpadmin hive yarn; do    
    adduser --uid $uid --gid $user $user
    uid=$(($uid + 1))
done

groupmems --group hadoop --add gpadmin
groupmems --group hadoop --add yarn

# Ignore errors.
true

