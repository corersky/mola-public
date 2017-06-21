#!/bin/sh
echo "export DAS_DEPLOY_MODE=$DEPLOY_MODE" >> /Datameer/etc/das-env.sh && echo -e "system.property.db.host=$MYSQL_HOST\nsystem.property.db.port=$MYSQL_PORT" >> /Datameer/conf/default.properties
cd /Datameer
./bin/conductor.sh start
touch logs/conductor.log
tail -f logs/conductor.log