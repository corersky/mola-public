#!/bin/sh
echo "Preparing /etc/hosts."
cat /tmp/hosts.addon >> /etc/hosts
cat /etc/hosts

ping -c 1 ${CLUSTERNODE}

echo "Configuring MapR client with cluster $CLUSTERNAME. Joining to node $CLUSTERNODE."
/opt/mapr/server/configure.sh -N ${CLUSTERNAME} -c -C ${CLUSTERNODE}

echo "Setup of datameer user directory in hdfs."
hadoop fs -mkdir /user/datameer
hadoop fs -chown -R datameer:datameer /user/datameer
echo "done."

echo "export DAS_DEPLOY_MODE=$DEPLOY_MODE" >> /Datameer/etc/das-env.sh && echo -e "system.property.db.host=$MYSQL_HOST\nsystem.property.db.port=$MYSQL_PORT" >
> /Datameer/conf/default.properties
cd /Datameer
touch logs/conductor.log

./bin/conductor.sh check
./bin/conductor.sh start

tail -100 logs/conductor.log
