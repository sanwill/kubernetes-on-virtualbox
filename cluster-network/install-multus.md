# Install Multus CNI

Reference: [Multus quick start](https://github.com/k8snetworkplumbingwg/multus-cni/blob/master/docs/quickstart.md)

* Verify if all nodes are in ready state.

```
# kubectl get nodes
NAME               STATUS   ROLES                  AGE     VERSION
c06-diy-master     Ready    control-plane,master   6d18h   v1.23.3
c06-diy-worker01   Ready    <none>                 7m26s   v1.23.3
c06-diy-worker02   Ready    <none>                 7m19s   v1.23.3
```

* Clone multus
```
# mkdir ~/multus
# cd ~/multus
# git clone https://github.com/k8snetworkplumbingwg/multus-cni.git && cd multus-cni
Cloning into 'multus-cni'...
remote: Enumerating objects: 36168, done.
remote: Counting objects: 100% (62/62), done.
remote: Compressing objects: 100% (53/53), done.
remote: Total 36168 (delta 26), reused 28 (delta 9), pack-reused 36106
Receiving objects: 100% (36168/36168), 46.07 MiB | 29.78 MiB/s, done.
Resolving deltas: 100% (15990/15990), done.

# ls -1
cmd
CODE_OF_CONDUCT.md
CONTRIBUTING.md
deployments
docs
e2e
examples
go.mod
go.sum
hack
images
LICENSE
pkg
README.md
vendor
```

* Install Multus
```
cat ./deployments/multus-daemonset-thick-plugin.yml | kubectl apply -f -
customresourcedefinition.apiextensions.k8s.io/network-attachment-definitions.k8s.cni.cncf.io created
clusterrole.rbac.authorization.k8s.io/multus created
clusterrolebinding.rbac.authorization.k8s.io/multus created
serviceaccount/multus created
daemonset.apps/kube-multus-ds created
```
Verify Multus resources have been created
```
# kubectl get pods -A | grep -i multus
kube-system        kube-multus-ds-djrvt                       1/1     Running   0             105s
kube-system        kube-multus-ds-hm8f5                       1/1     Running   0             105s
kube-system        kube-multus-ds-w4gx5                       1/1     Running   0             105s
```

* Create additional interfaces
Run on master node:
```
cat <<EOF | kubectl create -f -
apiVersion: "k8s.cni.cncf.io/v1"
kind: NetworkAttachmentDefinition
metadata:
  name: macvlan-conf
spec:
  config: '{
      "cniVersion": "0.3.1",
      "type": "macvlan",
      "master": "enp0s9",
      "mode": "bridge",
      "ipam": {
        "type": "host-local",
        "subnet": "192.168.64.0/24",
        "rangeStart": "192.168.64.10",
        "rangeEnd": "192.168.64.200",
        "routes": [
          { "dst": "0.0.0.0/0" }
        ],
        "gateway": "192.168.64.1"
      }
    }'
EOF
```

**Note:**  
* ```"master": "enp0s9"``` - Interface name on the hosts in your cluster to handle the traffic.
* ```"cniVersion": "0.3.1"``` - Multus CNI version.
See:
```
# cat /etc/cni/net.d/00-multus.conf  | python3 -m json.tool | grep -i version
    "cniVersion": "0.3.1",
            "cniVersion": "0.3.1",
```

Verify NetworkAttachmentDefinition
```
# kubectl get network-attachment-definitions
NAME           AGE
macvlan-conf   13s

# kubectl describe network-attachment-definitions macvlan-conf
Name:         macvlan-conf
Namespace:    default
Labels:       <none>
Annotations:  <none>
API Version:  k8s.cni.cncf.io/v1
Kind:         NetworkAttachmentDefinition
Metadata:
  Creation Timestamp:  2022-02-10T19:19:02Z
  Generation:          1
  Managed Fields:
    API Version:  k8s.cni.cncf.io/v1
    Fields Type:  FieldsV1
    fieldsV1:
      f:spec:
        .:
        f:config:
    Manager:         kubectl-create
    Operation:       Update
    Time:            2022-02-10T19:19:02Z
  Resource Version:  27261
  UID:               7a199312-9df7-4193-bb86-863c28a45217
Spec:
  Config:  { "cniVersion": "0.3.1", "type": "macvlan", "master": "enp0s9", "mode": "bridge", "ipam": { "type": "host-local", "subnet": "192.168.64.0/24", "rangeStart": "192.168.64.10", "rangeEnd": "192.168.64.200", "routes": [ { "dst": "0.0.0.0/0" } ], "gateway": "192.168.64.1" } }
Events:    <none>
```

# Create Test PODs

* Verify multus CNI by creating test pod which will have multiple interface.
See see ```annotations: k8s.v1.cni.cncf.io/networks: macvlan-conf```
```
cat <<EOF | kubectl create -f -
apiVersion: v1
kind: Pod
metadata:
  name: samplepod
  annotations:
    k8s.v1.cni.cncf.io/networks: macvlan-conf
spec:
  containers:
  - name: samplepod
    command: ["/bin/ash", "-c", "trap : TERM INT; sleep infinity & wait"]
    image: alpine
EOF

root@c06-diy-master:~/multus/multus-cni# kubectl exec -it samplepod -- ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
3: eth0@if9: <BROADCAST,MULTICAST,UP,LOWER_UP,M-DOWN> mtu 1450 qdisc noqueue state UP 
    link/ether fa:cf:99:24:18:1e brd ff:ff:ff:ff:ff:ff
    inet 10.248.93.193/32 scope global eth0
       valid_lft forever preferred_lft forever
4: net1@net1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP 
    link/ether 9a:c6:fd:05:7e:5f brd ff:ff:ff:ff:ff:ff
    inet 192.168.64.10/24 brd 192.168.64.255 scope global net1
       valid_lft forever preferred_lft forever
```

Pod with more interfaces, see ```annotations: k8s.v1.cni.cncf.io/networks: macvlan-conf,macvlan-conf```
```
# cat <<EOF | kubectl create -f -
apiVersion: v1
kind: Pod
metadata:
  name: samplepod2
  annotations:
    k8s.v1.cni.cncf.io/networks: macvlan-conf,macvlan-conf
spec:
  containers:
  - name: samplepod2
    command: ["/bin/ash", "-c", "trap : TERM INT; sleep infinity & wait"]
    image: alpine
EOF

# kubectl exec -it samplepod2 -- ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
3: eth0@if10: <BROADCAST,MULTICAST,UP,LOWER_UP,M-DOWN> mtu 1450 qdisc noqueue state UP 
    link/ether 6a:a8:bb:0f:af:8a brd ff:ff:ff:ff:ff:ff
    inet 10.248.93.194/32 scope global eth0
       valid_lft forever preferred_lft forever
4: net1@net1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP 
    link/ether ca:4c:0a:68:c7:ca brd ff:ff:ff:ff:ff:ff
    inet 192.168.64.11/24 brd 192.168.64.255 scope global net1
       valid_lft forever preferred_lft forever
5: net2@net1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP 
    link/ether 4e:63:43:e5:cd:b7 brd ff:ff:ff:ff:ff:ff
    inet 192.168.64.12/24 brd 192.168.64.255 scope global net2
       valid_lft forever preferred_lft forever
```

Compare the above outputs with pod without annotations to use macvlan-conf
```
# cat <<EOF | kubectl create -f -
apiVersion: v1
kind: Pod
metadata:
  name: samplepod3
spec:         
  containers:                                             
  - name: samplepod3
    command: ["/bin/ash", "-c", "trap : TERM INT; sleep infinity & wait"]
    image: alpine                                                        
EOF                                                                      

# kubectl exec -it samplepod3 -- ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
3: eth0@if9: <BROADCAST,MULTICAST,UP,LOWER_UP,M-DOWN> mtu 1450 qdisc noqueue state UP 
    link/ether ee:1c:b1:87:1e:b1 brd ff:ff:ff:ff:ff:ff
    inet 10.248.177.193/32 scope global eth0
       valid_lft forever preferred_lft forever
```

As you can see on pod ```samplepo``` and ```samplepod3```, the ```net1@net1``` and ```net2@net1``` are the additional interfaces created by Multus CNI.
The IP addresses are part of IP range we configured on NetworkAttachmentDefinition ```macvlan-conf```.  



At the above ```macvlan-conf``` configuration, I added addtional created host-only network (192.168.64.0/24) on VirtualBox and add additional adapter (appear as enp0s9 in Ubuntu) all VirtualBox VMs. However, you may use existing [enp0s8](https://github.com/sanwill/kubernetes-on-virtualbox/edit/main/README.md#preparation) and use cidr 192.168.70.0/24 with certain range (e.g. 192.168.70.100-192.168.70.150)

