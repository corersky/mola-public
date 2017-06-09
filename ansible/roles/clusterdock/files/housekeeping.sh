#!/bin/bash

DIST="cloudera"
echo "Removing ${DIST} containers."
CONTAINERS=`docker ps -a -q -f status=exited | grep ${DIST} | awk '{print $1}'`
[ ! -z ${CONTAINERS} ] && echo ${CONTAINERS} | xargs docker rm 

echo "Removing ${DIST} images."
IMAGES=`docker images | grep ${DIST} | awk '{print $3}'`
[ ! -z ${IMAGES} ] && echo ${IMAGES} | xargs docker rmi -f
