#!/bin/sh

USER_HOST=root@$1
MOUNT=$2
NFSPATH=$3

echo ${USER_HOST}
ssh ${USER_HOST} "umount ${MOUNT} ; mkdir -p ${MOUNT}" || exit
ssh ${USER_HOST} "grep -v ${MOUNT} /etc/fstab > /tmp/fstab ; cp /tmp/fstab /etc/fstab" || exit
ssh ${USER_HOST} "echo ${NFSPATH}  ${MOUNT}	nfs	nolock,nfsvers=3,tcp,rw,hard,intr,timeo=600,retrans=2,rsize=131072,wsize=524288 >> /etc/fstab" || exit
ssh ${USER_HOST} "mount -a; ls -lh ${MOUNT}" || exit

