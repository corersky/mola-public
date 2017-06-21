#!/bin/sh
echo "Preparing /etc/hosts."
cat /tmp/hosts.addon >> /etc/hosts
cat /etc/hosts
echo 
ping -c 1 ${CLUSTERNODE}
echo
echo "Configuring MapR client with cluster $CLUSTERNAME. Joining to node $CLUSTERNODE."
/opt/mapr/server/configure.sh -N ${CLUSTERNAME} -c -C ${CLUSTERNODE}
echo
echo "Setup of Datameer /user directory in hdfs."
hadoop fs -mkdir /user/datameer
hadoop fs -chown -R datameer:datameer /user/datameer
echo
hadoop fs -ls /user
echo "done."
echo
echo "export DAS_DEPLOY_MODE=$DEPLOY_MODE" >> /Datameer/etc/das-env.sh && echo -e "system.property.db.host=$MYSQL_HOST\nsystem.property.db.port=$MYSQL_PORT" >
> /Datameer/conf/default.properties
cd /Datameer
touch logs/conductor.log

echo "Datameer application check."
./bin/conductor.sh check
echo "done."
echo
echo "Datameer application start."
./bin/conductor.sh start
echo "done."
echo
echo "Opening logs".
tail -f logs/conductor.log
