hadoop fs -rm -r -f -skipTrash out
hadoop fs -ls -h in
hadoop jar /opt/cloudera/parcels/CDH/lib/hadoop-mapreduce/hadoop-mapreduce-examples.jar wordcount in out
hadoop fs -cat out/part-r-*
