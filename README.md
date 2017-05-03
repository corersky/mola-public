# project mola-public


## Ansible script for automatic deployment of docker environment

### Used hosts
To change destination you should create new hostgroup and add machines there. 
To change authorized user changed ansible_user to new value.

```
*$ cat ansible/hosts*
[AWS]
clustertest ansible_connection=ssh ansible_host=ec2-54-154-134-102.eu-west-1.compute.amazonaws.com ansible_user=max 
```

### Ansible roles
| role | usage |
| --- | --- |
|  `bootstrap` | basic machine setup |
|  `clusterdock` | CDH cluster setup |
|  `docker-hdp` | HDP cluster setup |
|  `Stouts.openvpn` | OpenVPN setup |

### Ansible commands

*preview mode*
```ansible-playbook clustertest.yml -i hosts -sC```

*sudo mode*
```ansible-playbook clustertest.yml -i hosts -s```
