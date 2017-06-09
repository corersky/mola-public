#!/bin/bash
# Cleaning script for clustertest 
# Created by michal@maxian.sk

DIST="mapr"
echo "Removing ${DIST} containers."
CONTAINERS=`docker ps -a -q -f status=exited | grep ${DIST} | awk '{print $1}'`
[ ! -z ${CONTAINERS} ] && echo ${CONTAINERS} | xargs docker rm 