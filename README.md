# project mola-public

Automated testing for Cloudera and HortonWorks Hadoop ecosystem.

# Ansible script for automatic deployment of docker environment

## Ansible environment setup
Check if you have ansible installed:
* Linux 
  * ```apt install ansible```
* OSX 
  * ```brew install ansible```
* on Windows install ansible with pip (it's possible to use pip also on Linux and OSX) 
  * ```pip install ansible```

### Ansible prerequisities 
* python
* Jinja2
* PyYAML
* paramiko
* httplib2
* sshpass

[Installation procedures for Ansible](http://docs.ansible.com/ansible/intro_installation.html)

## Clone ansible tasks repository
```
git clone git@github.com:Datameer-Inc/mola-public.git
cd mola-public/ansible
```

## Used hosts
To change destination you should create new hostgroup and add machines there. 
To change user change ansible_user to your valid login credentials.

```
$ cat ansible/hosts
[AWS]
clustertest ansible_connection=ssh ansible_host=ec2-54-154-134-102.eu-west-1.compute.amazonaws.com ansible_user=YOUR_USER 
```

## Ansible roles
| role | usage |
| --- | --- |
|  bootstrap | basic machine setup, added docker installation from official docker repository |
|  clusterdock | CDH cluster setup |
|  docker-hdp | HDP cluster setup |
|  docker-mapr | MapR cluster setup |
|  Stouts.openvpn | OpenVPN setup |

## Ansible commands

**preview mode**
* ```ansible-playbook clustertest.yml -i hosts -sC```

**sudo mode**
* ```ansible-playbook clustertest.yml -i hosts -s```

**sudo mode with query for sudo password**
* ```ansible-playbook clustertest.yml -i hosts -sK```

## clustertest scripts
Scripts are deployed in ```/opt/clustertest```.
You can see directory ```cdh``` for Cloudera and directory ```hdp``` for HortonWorks stack. 

### Cloudera ```cdh``` folder
```
/opt/clustertest # ls -l cdh/
total 16
--wxrw--wt 1 root root 274 Jun  9 10:39 clean.sh
--wxrw--wt 1 root root 427 Jun  9 10:39 housekeeping.sh
--wxrw--wt 1 root root 150 Jun  5 19:03 start.sh
--wxrw--wt 1 root root  72 Jun  8 14:01 stop.sh
```
* start.sh, stop.sh - start/stop scripts
* clean.sh - cleaning of container images
* housekeeping.sh - removal of all docker images and containers

### HortonWorks ```hdp``` folder
```
/opt/clustertest # ls -l hdp/
total 292
--wxrw--wt 1 root root    283 Jun  9 10:40 clean.sh
--w----r-T 1 root root 259574 Jun  5 19:03 HDP_hbase_dump_blueprint.json
--w----r-T 1 root root  10866 Jun  5 19:03 hive_config.json
--w----r-T 1 root root    322 Jun  5 19:03 hostmapping_multi.json
--wxrw--wt 1 root root    422 Jun  9 10:39 housekeeping.sh
--wxrw--wt 1 root root    351 Jun  5 19:03 repo-source.sh
--wxrw--wt 1 root root   1687 Jun  6 08:18 start.sh
--wxrw--wt 1 root root    112 Jun  5 19:03 stop.sh
```
* start.sh, stop.sh - start/stop scripts
* clean.sh - cleaning of container images
* housekeeping.sh - removal of all docker images and containers 
* HDP_hbase_dump_blueprint.json - Ambari blueprint
* hostmapping_multi.json - Ambari hosts definition
* hive_config.json - Ambari modification for Hive  
* repo-source.sh - HDP and Ambari repository definition

### MapR ```mapr``` folder
```
/opt/clustertest # ls -l mapr/
total 24
--wxrw--wt 1 root root  269 Jun  9 10:40 clean.sh
--wxrw--wt 1 root root  423 Jun  9 10:40 housekeeping.sh
--wxrw--wt 1 root root  233 Jun  5 19:04 setup-host.sh
--wxrw--wt 1 root root 4862 Jun  8 10:50 start.sh
--wxrw--wt 1 root root 1804 Jun  8 10:14 stop.sh
```
* start.sh, stop.sh - start/stop scripts
* clean.sh - cleaning of container images
* housekeeping.sh - removal of all docker images and containers 
* CLUSTERTEST.diskloop and CLUSTERTEST.disklv are files with values of used disks for MapR instance CLUSTERTEST

### Starting and stopping scripts
| Distribution | Cloudera | HortonWorks | MapR | 
| --- | :---: | :---: | :---: | 
| Utility | Cloudera Manager | Ambari | Mapr Control System  |
| Start script | ```/opt/clustertest/cdh/start.sh``` | ```/opt/clustertest/hdp/start.sh```  | ```/opt/clustertest/mapr/start.sh``` Usage : ./start.sh ClusterName NumberOfNodes MemSize-in-kB  |
| Stop script | ```/opt/clustertest/cdh/stop.sh``` | ```/opt/clustertest/hdp/stop.sh``` | ```/opt/clustertest/mapr/stop.sh``` Usage : ./stop.sh ClusterName |
| Cleaning script | ```/opt/clustertest/cdh/clean.sh``` | ```/opt/clustertest/hdp/clean.sh``` | ```/opt/clustertest/mapr/clean.sh``` | 
| Housekeeping script | ```/opt/clustertest/cdh/housekeeping.sh``` | ```/opt/clustertest/hdp/housekeeping.sh``` | ```/opt/clustertest/mapr/housekeeping.sh``` | 
| Download time | ~40 min. | ~40 min. | ~12min. |
| Starting time | ~10 min. | ~15 min. | ~4min. | 
| Stopping time | ~1 min. | ~2 min. | ~1min. |


#### Cloudera docker status
```
/opt/clustertest/cdh # docker ps
CONTAINER ID        IMAGE                                                        COMMAND             CREATED             STATUS              PORTS                                              NAMES
27f8d1ffd20b        docker.io/cloudera/clusterdock:cdh580_cm581_secondary-node   "/sbin/init"        2 hours ago         Up 2 hours                                                             tender_shaw
9042dcaf1044        docker.io/cloudera/clusterdock:cdh580_cm581_secondary-node   "/sbin/init"        2 hours ago         Up 2 hours                                                             happy_lamarr
91ea72a97fbd        docker.io/cloudera/clusterdock:cdh580_cm581_secondary-node   "/sbin/init"        2 hours ago         Up 2 hours                                                             thirsty_torvalds
15e9e562cbd2        docker.io/cloudera/clusterdock:cdh580_cm581_primary-node     "/sbin/init"        2 hours ago         Up 2 hours          0.0.0.0:32773->7180/tcp, 0.0.0.0:32772->8888/tcp   clever_hypatia
```

#### HortonWorks docker status
```
/opt/clustertest/hdp # docker ps
CONTAINER ID        IMAGE               COMMAND                  CREATED             STATUS              PORTS                NAMES
b55a04495df0        hdp/master          "/bin/sh -c /start.sh"   12 seconds ago      Up 9 seconds        0.0.0.0:2181->2181/tcp, 0.0.0.0:3000->3000/tcp, 0.0.0.0:6080->6080/tcp, 0.0.0.0:6083->6083/tcp, 0.0.0.0:6182-6183->6182-6183/tcp, 0.0.0.0:8000->8000/tcp, 0.0.0.0:8020->8020/tcp, 0.0.0.0:8025->8025/tcp, 0.0.0.0:8030->8030/tcp, 0.0.0.0:8050->8050/tcp, 0.0.0.0:8088->8088/tcp, 0.0.0.0:8141->8141/tcp, 0.0.0.0:8188->8188/tcp, 0.0.0.0:8190->8190/tcp, 0.0.0.0:8443->8443/tcp, 0.0.0.0:8744->8744/tcp, 0.0.0.0:9000->9000/tcp, 0.0.0.0:9933->9933/tcp, 0.0.0.0:9995->9995/tcp, 0.0.0.0:9999-10000->9999-10000/tcp, 0.0.0.0:10015->10015/tcp, 0.0.0.0:10200->10200/tcp, 0.0.0.0:11000->11000/tcp, 0.0.0.0:11443->11443/tcp, 0.0.0.0:16000->16000/tcp, 0.0.0.0:16010->16010/tcp, 0.0.0.0:19888->19888/tcp, 0.0.0.0:45454->45454/tcp, 0.0.0.0:50090->50090/tcp   compose_master0.dev_1
81f6610c7994        hdp/worker          "/bin/sh -c /start.sh"   12 seconds ago      Up 10 seconds       0.0.0.0:6667->6667/tcp, 0.0.0.0:8042->8042/tcp, 0.0.0.0:8983->8983/tcp, 0.0.0.0:16020->16020/tcp, 0.0.0.0:16030->16030/tcp, 0.0.0.0:50010->50010/tcp, 0.0.0.0:50020->50020/tcp, 0.0.0.0:50030->50030/tcp, 0.0.0.0:50070->50070/tcp, 0.0.0.0:50075->50075/tcp, 0.0.0.0:50470->50470/tcp, 0.0.0.0:50475->50475/tcp, 0.0.0.0:45455->45454/tcp   compose_dn0.dev_1
d58973a7e72b        hdp/ambari-server   "/bin/sh -c /start.sh"   12 seconds ago      Up 10 seconds       0.0.0.0:8080->8080/tcp   compose_ambari-server.dev_1
178272b04fb1        hdp/postgres        "docker-entrypoint..."   12 seconds ago      Up 10 seconds       5432/tcp     compose_postgres.dev_1
```

#### MapR docker status
```
/opt/clustertest/hdp # docker ps
CONTAINER ID        IMAGE                                          COMMAND                  CREATED             STATUS              PORTS               NAMES
0f28cd61a950        docker.io/maprtech/mapr-data-cent67:5.2.0      "/bin/sh -c /usr/b..."   47 hours ago        Up 47 hours                             zen_nobel
f718f13757c9        docker.io/maprtech/mapr-data-cent67:5.2.0      "/bin/sh -c /usr/b..."   47 hours ago        Up 47 hours                             objective_cray
9b6b6ad40d10        docker.io/maprtech/mapr-control-cent67:5.2.0   "/bin/sh -c /usr/b..."   47 hours ago        Up 47 hours                             wonderful_kirch
```