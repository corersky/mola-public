# project mola-public

Automated testing for Cloudera and HortonWorks Hadoop ecosystem.

# Ansible script for automatic deployment of docker environment

## Used hosts
To change destination you should create new hostgroup and add machines there. 
To change authorized user changed ansible_user to new value.

```
*$ cat ansible/hosts*
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


## Hadoop scripts
Scripts are deployed in ```/opt/clustertest```.
You can see directory ```cdh``` for Cloudera and directory ```hdp``` for HortonWorks stack. 
```
/opt/clustertest # ls -l cdh
total 8
--wxrw--wt 1 root root 207 May  4 13:19 housekeeping.sh
--wxrw--wt 1 root root 150 May  4 13:19 start.sh
```

```
/opt/clustertest # ls -l hdp
total 276
--w----r-T 1 root root 259574 May  4 13:19 HDP_hbase_dump_blueprint.json
--w----r-T 1 root root  10866 May  4 13:19 hive_config.json
--w----r-T 1 root root    322 May  4 13:19 hostmapping_multi.json
--wxrw--wt 1 root root   1628 May  4 13:19 start.sh
```

Starting scripts are:
- ```/opt/clustertest/cdh/start.sh``` for Cloudera stack
- ```/opt/clustertest/hdp/start.sh``` for HortonWorks stack
