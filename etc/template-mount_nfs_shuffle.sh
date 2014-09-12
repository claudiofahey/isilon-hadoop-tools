#!/bin/sh
mount=/mnt/isiloncluster1/isiloncluster1/system
rm -f /data/nfs1
mkdir -p $mount/hadoop-local-data/`hostname`-1
ln -s -f $mount/hadoop-local-data/`hostname`-1 /data/nfs1

