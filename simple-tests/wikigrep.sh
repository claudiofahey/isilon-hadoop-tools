hadoop fs -rm -r -f -skipTrash hdfs://all-nc-s-hdfs/user/hduser1/output

hadoop jar \
/opt/cloudera/parcels/CDH/lib/hadoop-mapreduce/hadoop-mapreduce-examples.jar \
grep hdfs://all-nc-s-hdfs/user/hduser1/wikidata hdfs://all-nc-s-hdfs/user/hduser1/output "EMC [^ ]*"

