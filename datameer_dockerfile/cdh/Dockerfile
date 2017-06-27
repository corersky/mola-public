FROM anapsix/alpine-java:7

MAINTAINER Tom Köckeritz <tkoeckeritz@datameer.com>

EXPOSE 8080

ENV DEPLOY_MODE=trial MYSQL_HOST=localhost MYSQL_PORT=3306

ADD Datameer-* /Datameer/
ADD service_start.sh /Datameer/
ADD http://cdn.mysql.com//Downloads/Connector-J/mysql-connector-java-5.1.40.tar.gz /Datameer/etc/custom-jars

RUN tar -C /Datameer/etc/custom-jars -xzf /Datameer/etc/custom-jars/mysql-connector-java-5.1.40.tar.gz mysql-connector-java-5.1.40/mysql-connector-java-5.1.40-bin.jar
RUN chmod +x /Datameer/service_start.sh

ENTRYPOINT ["/Datameer/service_start.sh"]