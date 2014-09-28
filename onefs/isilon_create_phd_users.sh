#!/bin/bash

zone=system
homedir=/ifs/all-nc-virtisi2/system/hadoop/user
gid_base=601
uid_base=601

gid=$gid_base
for group in hdfs mapred hbase hive yarn oozie sentry spark hue sqoop2 solr sqoop httpfs zookeper flume gpadmin hadoop supergroup pxf postgres; do
    isi auth groups create $group --zone $zone --provider local --gid $gid
    gid=$(($gid + 1))
done

uid=$uid_base
for user in hdfs mapred hbase hive yarn oozie sentry spark hue sqoop2 solr sqoop httpfs zookeper flume gpadmin hadoop pxf postgres; do    
    isi auth users create $user --zone $zone --provider local --uid $uid --primary-group $user --home-directory $homedir/$user
    uid=$(($uid + 1))
done

isi auth groups modify hadoop --add-user hdfs --zone $zone
isi auth groups modify hadoop --add-user yarn --zone $zone
isi auth groups modify hadoop --add-user mapred --zone $zone
isi auth groups modify supergroup --add-user hdfs --zone $zone
isi auth groups modify supergroup --add-user yarn --zone $zone
isi auth groups modify supergroup --add-user mapred --zone $zone

