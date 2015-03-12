#!/bin/bash

gid_base=1000
uid_base=1000

#for user in hdfs mapred hbase hive yarn oozie sentry impala spark hue sqoop2 solr sqoop httpfs llama zookeper flume sample; do    
#    userdel -f -r $user
#done

#for group in hdfs mapred hbase hive yarn oozie sentry impala spark hue sqoop2 solr sqoop httpfs llama zookeper flume sample hadoop supergroup; do
#    groupdel $group
#done

gid=$gid_base
for group in hdfs mapred hbase hive yarn oozie sentry impala spark hue sqoop2 solr sqoop httpfs llama zookeper flume sample hadoop supergroup; do
    groupadd --gid $gid $group
    gid=$(($gid + 1))
done

uid=$uid_base
for user in hdfs mapred hbase hive yarn oozie sentry impala spark hue sqoop2 solr sqoop httpfs llama zookeper flume sample; do    
    adduser --uid $uid --gid $user $user
    uid=$(($uid + 1))
done

groupmems --group hadoop --add hdfs
groupmems --group hadoop --add yarn
groupmems --group hadoop --add mapred
groupmems --group hdfs --add impala
groupmems --group sqoop --add sqoop2
groupmems --group hive --add impala

# Ignore errors.
true

