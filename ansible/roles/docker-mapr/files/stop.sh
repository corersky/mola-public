#!/bin/bash

if [[ -z $(which docker)  ]] ; then
        echo " docker could not be found on this server. Please install Docker version 1.6.0 or later."
	echo " If it is already installed Please update the PATH env variable." 
        exit
fi

dv=$(docker --version | awk '{ print $3}' | sed 's/,//')
if [[ $dv < 1.6.0 ]] ; then
        echo " Docker version installed on this server : $dv.  Please install Docker version 1.6.0 or later."
        exit
fi

# Usage Check.
if [[ $# -ne 1 ]]
then
	echo " Usage : $0 ClusterName"
	exit
fi

CLUSTERNAME=$1

DISKLISTFILE=$CLUSTERNAME.diskloop # file to store used loop devices
DISKLVFILE=$CLUSTERNAME.disklv # file to store used LV volumes

DISKFILES=`cat $DISKLISTFILE`
DISKNUMBER=`cat $DISKLISTFILE | wc -l`
DISKLV=`cat $DISKLVFILE`

DOCKER_CONTAINERS=`docker ps | grep maprtech | awk '{print $1}'`

if [ ! -f $DISKLISTFILE ]; then
 echo "$DISKLISTFILE doesn't exist!"
 exit
fi

if [ ! -f $DISKLVFILE ]; then
 echo "$DISKLVFILE doesn't exist!"
 exit
fi

for container in ${DOCKER_CONTAINERS}
do
  echo "Stopping container $container:"
  docker ps | grep $container
  docker stop $container && echo "done." || echo "problem with stopping container."
done

for lodevice in $DISKFILES
do 
  ### deletion with lvremove /dev/$VG/lv$CLUSTERNAME$i
  echo "Removing loopback device $lodevice"
  losetup -vd $lodevice && echo "$lodevice removed." || echo "ehm problem occured!"
done 
rm -v $DISKLISTFILE

for lv in $DISKLV
do
  echo "Removing logical volume $lv"
  lvremove -f $lv && echo "$lv removed." || echo "some problem with lv removal".
done
rm -v $DISKLVFILE

# LOOPDEVICES=`losetup -a`
### dynamic load for removal (from losetup -a)
#losetup -a | \
#while read line; do
#    echo $line | awk -F: '{print $1}'
#    echo $line | sed -r '/[a-z][A-Z]*$/p'
#done
