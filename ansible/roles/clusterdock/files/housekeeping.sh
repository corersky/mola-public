#!/bin/bash
docker ps | grep -v CONTAINER | awk '{print $1}' | xargs docker kill
docker rm -v $(docker ps -a -q -f status=exited)
docker images | grep -v REPOSITORY | awk '{print $3}' | xargs docker rmi -f

