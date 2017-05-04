#!/bin/bash
docker stop $(docker ps | grep cdh | awk '{print $1}')
