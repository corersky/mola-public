#!/bin/bash
source ./clusterdock.sh
clusterdock_run ./bin/start_cluster cdh --primary-node=node-1 --secondary-nodes='node-{2..4}'
