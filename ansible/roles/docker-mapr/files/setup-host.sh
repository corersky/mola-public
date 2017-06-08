#!/bin/bash

ip link add bridge0 type bridge
ip addr add 10.10.100.0/24 dev bridge0
ip link set bridge0 up

# create list of disks
# create disks 
# create loop devices for each disk

# test if # of disks are the same as # of nodes

