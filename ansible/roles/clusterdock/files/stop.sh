#!/bin/bash
psstring="cloudera"
RET=$(docker ps | grep ${psstring} | awk '{print $1}')
if [ ${RET} ]
then
  docker stop $(docker ps | grep cloudera | awk '{print $1}')
else
  echo "No containers marked as ${psstring}."
fi