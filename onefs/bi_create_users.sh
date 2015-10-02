#!/bin/bash

gid_base=1000
uid_base=1000

#for user in hdfs mapred hbase knox dbus uiuser dsmadmin bigsheets ambari-qa rrdcached hive yarn hcat bigsql tauser bigr flume nagios solr spark sqoop zookeeper oozie; do
#    userdel -f -r $user
#done

#for group in hdfs mapred hbase knox uiuser dsmadmin bigsheets ambari-qa rrdcached hive yarn hcat bigsql tauser bigr flume nagios solr spark sqoop zookeeper oozie; do
#    groupdel $group
#done

gid=$gid_base
for group in hdfs hadoop mapred hbase knox uiuser dsmadmin bigsheets ambari-qa rrdcached hive yarn hcat bigsql tauser bigr flume nagios solr spark sqoop zookeeper oozie bighome; do
    groupadd --gid $gid $group
    gid=$(($gid + 1))
done

uid=$uid_base
for user in hdfs hadoop mapred hbase knox uiuser dsmadmin bigsheets ambari-qa rrdcached hive yarn hcat bigsql tauser bigr flume nagios solr spark sqoop zookeeper oozie bighome; do
    adduser --uid $uid --gid $user $user
    uid=$(($uid + 1))
done

groupmems --group hadoop --add hdfs
groupmems --group hadoop --add yarn
groupmems --group hadoop --add mapred
groupmems --group hdfs --add bigsql
groupmems --group hadoop --add bigsql
groupmems --group hive --add bigsql
groupmems --group users --add hive
groupmems --group hcat --add hive


# Ignore errors.
true