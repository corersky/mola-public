FROM centos:latest

MAINTAINER Michal Maxian <michal@maxian.sk>

EXPOSE 8080

ENV DEPLOY_MODE=trial MYSQL_HOST=localhost MYSQL_PORT=3306

RUN groupadd datameer
RUN useradd --system -m -g datameer datameer
ADD Datameer-* /Datameer/
ADD service_start.sh /Datameer/
RUN chmod +x /Datameer/service_start.sh

#ADD jdk-7u80-linux-x64.rpm /tmp
ADD http://internal.repository.hadoop.s3.amazonaws.com/jdk/jdk-7u80-linux-x64.rpm /tmp
RUN rpm -iv /tmp/jdk-7u80-linux-x64.rpm
ENV JAVA_HOME=/usr/java/jdk1.7.0_80

ADD mapr.repo /etc/yum.repos.d/
RUN yum -y install net-tools which sudo
RUN yum -y install mapr-client mysql-connector-java
RUN yum -y clean all

ADD hosts.addon /tmp/hosts.addon

ARG CLUSTERNAME=MAPRC1
ARG CLUSTERNODE=${CLUSTERNAME}c1.mapr.io
ENV CLUSTERNAME $CLUSTERNAME
ENV CLUSTERNODE $CLUSTERNODE

ENTRYPOINT ["/Datameer/service_start.sh"]
