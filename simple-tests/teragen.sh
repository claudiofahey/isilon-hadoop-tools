mapred job -list | grep job_ | awk ' { system("mapred job -kill " $1) } '

hadoop fs -rm -r -f -skipTrash /benchmarks/streaming-21/hduser1/terasort/terasort-input

time hadoop jar \
/opt/cloudera/parcels/CDH/lib/hadoop-mapreduce/hadoop-mapreduce-examples.jar \
teragen \
-Ddfs.blocksize=512M \
-Dio.file.buffer.size=131072 \
-Dmapreduce.map.java.opts=-Xmx1536m \
-Dmapreduce.map.memory.mb=2048 \
-Dmapreduce.map.output.compress=true \
-Dmapreduce.map.output.compress.codec=org.apache.hadoop.io.compress.Lz4Codec \
-Dmapreduce.reduce.java.opts=-Xmx1536m \
-Dmapreduce.reduce.memory.mb=2048 \
-Dmapreduce.task.io.sort.factor=100 \
-Dmapreduce.task.io.sort.mb=256 \
-Dyarn.app.mapreduce.am.resource.mb=1024 \
-Dmapred.map.tasks=64 \
10000000000  \
/benchmarks/streaming-21/hduser1/terasort/terasort-input
