#!/bin/sh
echo "export DAS_DEPLOY_MODE=$DEPLOY_MODE" >> /Datameer/etc/das-env.sh && echo -e "system.property.db.host=$MYSQL_HOST\nsystem.property.db.port=$MYSQL_PORT" >> /Datameer/conf/default.properties
echo
cd /Datameer
echo "Datameer application check."
./bin/conductor.sh check
echo "done."
echo
echo "Datameer application start."
./bin/conductor.sh start
echo "done."
echo 
echo "Opening logs."
touch logs/conductor.log
tail -f logs/conductor.log
