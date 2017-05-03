#!/bin/bash

if [ $# -lt 1 ]; then
  SERVER="10.10.0.1:8080"
  echo "Using default value for SERVER configuraiton $SERVER"
  echo "Usage: $0 SERVERIP:PORT [default:10.10.0.1:8080]"
else
  SERVER=$1
  echo "Using SERVER value ${SERVER}"
fi

echo
echo "Starting Ambari setup"
echo
date
echo

echo "Waiting for Ambari server ${SERVER}"
until $(curl --output /dev/null --silent --head --fail http://${SERVER}); do
    printf '.'
    sleep 5
done
echo

echo "Ambari server ${SERVER} is UP!"
echo
echo "Setting blueprint"
curl -u admin:admin -H "X-Requested-By: ambari" -X POST http://${SERVER}/api/v1/blueprints/HDP-hbase -d @HDP_hbase_dump_blueprint.json
echo "done."
echo
echo "Setting up hostmapping"
curl -u admin:admin -H "X-Requested-By: ambari" -X POST http://${SERVER}/api/v1/clusters/HDP-hbase -d @hostmapping_multi.json
echo "done."

date
echo "Waiting for cluster."
echo
sleep 720

echo "Setting Hive Meta Store to docker postgres.dev container."
curl -H 'X-Requested-By: ambari' -X PUT -u admin:admin http://${SERVER}/api/v1/clusters/HDP-hbase -i -d @hive_config_2.json 
echo "done."
echo
echo "Restarting Hive."
curl -u admin:admin -i -H 'X-Requested-By: ambari' -X PUT -d '{"Body": {"ServiceInfo": {"state": "INSTALLED"}}}' http://${SERVER}/api/v1/clusters/HDP-hbase/services/HIVE
curl -u admin:admin -i -H 'X-Requested-By: ambari' -X PUT -d '{"Body": {"ServiceInfo": {"state": "STARTED"}}}' http://${SERVER}/api/v1/clusters/HDP-hbase/services/HIVE
echo "done."
echo
echo "Check server in 5 minutes."
date
