#!/bin/bash
docker stop $(docker ps | grep cloudera | awk '{print $1}')
