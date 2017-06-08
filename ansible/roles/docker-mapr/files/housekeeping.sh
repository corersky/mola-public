#!/bin/bash
docker ps -a -f status=exited | grep mapr | awk '{print $1}' | xargs docker rm
docker images | grep mapr | awk '{print $3}' | xargs docker rmi
