# Dockerfiles for Datameer application

## Requirements
Installation of 
* oracle java v7 or v8
* mysql-connector-java

## CDH and HortonWorks
We're using alpine linux with Java v7 preinstalled.
Cloudera and HortonWorks uses same Datameer application configuration.

## MapR
We're using centos distribution.

### Requirements
For MapR there're additional requirement for mapr-client installed from MapR repository.
Installation of Oracle Java v7 is installed from internal source hosted on S3.

```hosts.addon``` is added to ```/etc/hosts``` and it's fixed configuration for 3 node cluster.
