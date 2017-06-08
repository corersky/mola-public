#!/bin/bash
docker ps -a -f status=exited | grep mapr | awk '{print $1}' | xargs docker rm
