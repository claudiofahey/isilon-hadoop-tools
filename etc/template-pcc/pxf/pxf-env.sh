#!/bin/bash
# PXF service environment script

# Path to HDFS native libraries
export LD_LIBRARY_PATH=/usr/lib/gphd/hadoop/lib/native:${LD_LIBRARY_PATH}

# Path to JAVA, controlled by plugin
export JAVA_HOME=${cluster_java_home}


