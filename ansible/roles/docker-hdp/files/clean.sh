#!/bin/bash
if [ -f nohup.out] 
then
  echo Removing nohup.out output
  rm -vf nohup.out
fi
docker ps -a -f status=exited | grep hdp | awk '{print $2}' | xargs docker rm
