# The java implementation to use.  Required.
export JAVA_HOME=${cluster_java_home}

# The maximum amount of heap to use, in MB. Default is 1000.
export HADOOP_HEAPSIZE=1024
export HADOOP_NAMENODE_HEAPSIZE=${dfs.namenode.heapsize.mb}
export HADOOP_DATANODE_HEAPSIZE=${dfs.datanode.heapsize.mb}

# Extra Java runtime options. Empty by default.
export HADOOP_OPTS="-Djava.net.preferIPv4Stack=true ${HADOOP_OPTS}"

# Extra ssh options.  Empty by default.
export HADOOP_SSH_OPTS="-o ConnectTimeout=5 -o SendEnv=HADOOP_CONF_DIR"

# Set Hadoop-specific environment variables here.
# Command specific options appended to HADOOP_OPTS when specified
export HADOOP_NAMENODE_OPTS="-Dcom.sun.management.jmxremote -Xms${dfs.namenode.heapsize.mb}m -Xmx${dfs.namenode.heapsize.mb}m -Dhadoop.security.logger=INFO,DRFAS -Dhdfs.audit.logger=INFO,RFAAUDIT -XX:ParallelGCThreads=8 -XX:+UseParNewGC -XX:+UseConcMarkSweepGC -XX:+HeapDumpOnOutOfMemoryError -XX:ErrorFile=${HADOOP_LOG_DIR}/hs_err_pid%p.log $HADOOP_NAMENODE_OPTS"

export HADOOP_SECONDARYNAMENODE_OPTS="-Dcom.sun.management.jmxremote -Xms${dfs.namenode.heapsize.mb}m -Xmx${dfs.namenode.heapsize.mb}m -Dhadoop.security.logger=INFO,DRFAS -Dhdfs.audit.logger=INFO,RFAAUDIT -XX:ParallelGCThreads=8 -XX:+UseParNewGC -XX:+UseConcMarkSweepGC -XX:+HeapDumpOnOutOfMemoryError -XX:ErrorFile=${HADOOP_LOG_DIR}/hs_err_pid%p.log $HADOOP_SECONDARYNAMENODE_OPTS"

export HADOOP_DATANODE_OPTS="-Dcom.sun.management.jmxremote -Xms${dfs.datanode.heapsize.mb}m -Xmx${dfs.datanode.heapsize.mb}m -Dhadoop.security.logger=ERROR,DRFAS $HADOOP_DATANODE_OPTS"

export HADOOP_BALANCER_OPTS="-Dcom.sun.management.jmxremote -server -Xmx${HADOOP_HEAPSIZE}m $HADOOP_BALANCER_OPTS"

export HADOOP_JOBTRACKER_OPTS="-Dcom.sun.management.jmxremote $HADOOP_JOBTRACKER_OPTS"
# export HADOOP_TASKTRACKER_OPTS=
# The following applies to multiple commands (fs, dfs, fsck, distcp etc)
# export HADOOP_CLIENT_OPTS

# The following applies to multiple commands (fs, dfs, fsck, distcp etc)
export HADOOP_CLIENT_OPTS="-Xmx${HADOOP_HEAPSIZE}m $HADOOP_CLIENT_OPTS"

# GPHD variables
export GPHD_HOME=/usr/lib/gphd
export GPHD_CONF=/etc/gphd


HADOOP_CLASSPATH=$HADOOP_CLASSPATH:\
$GPHD_HOME/sm-plugins/*:

export HADOOP_CLASSPATH




