#!/bin/bash
docker ps -a -f status=exited | grep hdp | awk '{print $2}' | xargs docker rm
