#!/bin/bash
docker ps -a -q -f status=exited | grep cloudera | awk '{print $1}' | xargs docker rm
docker images | grep cloudera | awk '{print $3}' | xargs docker rmi -f
