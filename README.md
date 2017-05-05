# project mola-public

Automated testing for Cloudera and HortonWorks Hadoop ecosystem.

# Ansible script for automatic deployment of docker environment

## Used hosts
To change destination you should create new hostgroup and add machines there. 
To change authorized user changed ansible_user to new value.

```
$ cat ansible/hosts
[AWS]
clustertest ansible_connection=ssh ansible_host=ec2-54-154-134-102.eu-west-1.compute.amazonaws.com ansible_user=max 
```

## Ansible roles
| role | usage |
| --- | --- |
|  bootstrap | basic machine setup |
|  clusterdock | CDH cluster setup |
|  docker-hdp | HDP cluster setup |
|  Stouts.openvpn | OpenVPN setup |

## Ansible commands

**preview mode**
```ansible-playbook clustertest.yml -i hosts -sC```

**sudo mode**
```ansible-playbook clustertest.yml -i hosts -s```


## clustertest scripts
Scripts are deployed in ```/opt/clustertest```.
You can see directory ```cdh``` for Cloudera and directory ```hdp``` for HortonWorks stack. 

### HortonWorks ```hdp``` folder
```
# ls -l cdh
total 12
--wxrw--wt 1 root root 207 May  4 13:19 housekeeping.sh
--wxrw--wt 1 root root 150 May  4 13:19 start.sh
--wxrw--wt 1 root root  67 May  4 14:28 stop.sh
```

### Cloudera ```cdh``` folder
```
/opt/clustertest # ls -l hdp
total 284
--wxrw--wt 1 root root     88 May  4 14:18 clean.sh
--w----r-T 1 root root 259574 May  4 13:19 HDP_hbase_dump_blueprint.json
--w----r-T 1 root root  10866 May  4 13:19 hive_config.json
--w----r-T 1 root root    322 May  4 13:19 hostmapping_multi.json
--wxrw--wt 1 root root   1628 May  4 14:07 start.sh
--wxrw--wt 1 root root     88 May  4 14:06 stop.sh
```

### Starting and stopping scripts
| Distribution | Utility | Start script | Stop script | 
| --- | --- | --- | --- | 
| CDH | Cloudera Manager | ```/opt/clustertest/cdh/start.sh``` | ```/opt/clustertest/cdh/stop.sh``` | 
| HDP | Ambari | ```/opt/clustertest/hdp/start.sh``` | ```/opt/clustertest/hdp/stop.sh``` |
| MapR | | | |

### Action times
| Distribution | Starting time | Downloading time | Stopping time |
| --- | --- | --- | --- |
| CDH | ~15 min. | ~40 min. | ~2 min. |
| HDP | ~10 min. | ~40 min. | ~1 min |
| MapR | | | | 


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
