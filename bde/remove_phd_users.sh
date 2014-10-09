#!/bin/bash

for user in hdfs mapred hbase gpadmin hive yarn puppet zookeeper postgres tcserver pxf; do    
    userdel -f -r $user
done

for group in hdfs mapred hbase gpadmin hive yarn puppet zookeeper postgres tcserver pxf hadoop; do
    groupdel $group
    gid=$(($gid + 1))
done

