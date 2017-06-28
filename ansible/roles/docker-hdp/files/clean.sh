#!/bin/bash
if [ -f nohup.out ] 
then
  echo Removing nohup.out output
  rm -vf nohup.out
fi
DIST="hdp"
echo "Removing ${DIST} containers."
CONTAINERS=`docker ps -a -q -f status=exited | grep ${DIST} | awk '{print $1}'`
[ ! -z ${CONTAINERS} ] && echo ${CONTAINERS} | xargs docker rm 
