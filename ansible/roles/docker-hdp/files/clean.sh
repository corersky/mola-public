#!/bin/bash
echo Removing nohup.out output
rm -vf nohup.out
docker ps -a -f status=exited | grep hdp | awk '{print $2}' | xargs docker rm
