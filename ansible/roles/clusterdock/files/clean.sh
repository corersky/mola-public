#!/bin/bash
docker ps -a -f status=exited | grep cloudera | awk '{print $1}' | xargs docker rm
