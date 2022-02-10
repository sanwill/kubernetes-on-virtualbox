# Install Calico CNI
Reference: [Calico quick start](https://projectcalico.docs.tigera.io/getting-started/kubernetes/quickstart)

* Install the Tigera Calico operator and custom resource definitions/CRD.
```
# mkdir ~/calico
# cd ~/calico
# wget https://projectcalico.docs.tigera.io/manifests/tigera-operator.yaml
--2022-02-10 06:26:20--  https://projectcalico.docs.tigera.io/manifests/tigera-operator.yaml
Resolving projectcalico.docs.tigera.io (projectcalico.docs.tigera.io)... 67.207.80.24, 54.211.114.166, 2600:1f18:2489:8200:2005:c668:299e:b1e, ...
Connecting to projectcalico.docs.tigera.io (projectcalico.docs.tigera.io)|67.207.80.24|:443... connected.
HTTP request sent, awaiting response... 200 OK
Length: 306798 (300K) [text/yaml]
Saving to: ‘tigera-operator.yaml’

tigera-operator.yaml                            100%[=====================================================================================================>] 299.61K  1.50MB/s    in 0.2s    

2022-02-10 06:26:20 (1.50 MB/s) - ‘tigera-operator.yaml’ saved [306798/306798]


# kubectl create -f tigera-operator.yaml
customresourcedefinition.apiextensions.k8s.io/bgpconfigurations.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/bgppeers.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/blockaffinities.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/caliconodestatuses.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/clusterinformations.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/felixconfigurations.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/globalnetworkpolicies.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/globalnetworksets.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/hostendpoints.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/ipamblocks.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/ipamconfigs.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/ipamhandles.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/ippools.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/ipreservations.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/kubecontrollersconfigurations.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/networkpolicies.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/networksets.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/apiservers.operator.tigera.io created
customresourcedefinition.apiextensions.k8s.io/imagesets.operator.tigera.io created
customresourcedefinition.apiextensions.k8s.io/installations.operator.tigera.io created
customresourcedefinition.apiextensions.k8s.io/tigerastatuses.operator.tigera.io created
namespace/tigera-operator created
Warning: policy/v1beta1 PodSecurityPolicy is deprecated in v1.21+, unavailable in v1.25+
podsecuritypolicy.policy/tigera-operator created
serviceaccount/tigera-operator created
clusterrole.rbac.authorization.k8s.io/tigera-operator created
clusterrolebinding.rbac.authorization.k8s.io/tigera-operator created
deployment.apps/tigera-operator created
```

* Update the custom resource
```
# cd ~/calico
# wget https://projectcalico.docs.tigera.io/manifests/custom-resources.yaml
```
Change the default IP pool CIDR to match your pod network CIDR.  
For example, change ```cidr: 192.168.0.0/16``` to ```cidr: 10.211.0.0/16``` 

The ```10.211.0.0/16``` is the pod-network-cidr IP we were using while [initiate kubeadm](https://github.com/sanwill/kubernetes-on-virtualbox/edit/main/README.md#initializing-control-planemaster-node).

 

* Install Calico by creating the necessary custom resource. 
```
# kubectl create -f custom-resources.yaml0
installation.operator.tigera.io/default created
apiserver.operator.tigera.io/default created

```

Confirm that all of the pods are running with the following command.
```
# watch kubectl get pods -n calico-system
...
...
NAME                                       READY   STATUS    RESTARTS   AGE
calico-kube-controllers-77c48f5f64-csl2v   1/1     Running   0          2m12s
calico-node-fprb6                          1/1     Running   0          2m12s
calico-typha-77b7886f75-t5v52              1/1     Running   0          2m12s

```
At this point you can add the remaining nodes to master.For example:

* Run on master:
```
# kubeadm token create --print-join-command
```
* Run join command on worker nodes:
```
# kubeadm join 192.168.70.3:6443 --token ul3z4n.znd6xxxxxxxxxxxx \
        --discovery-token-ca-cert-hash sha256:xxxxxxxxxd6fde0f1e27e5bbb3d873f316a7d065fb5fe57517xxxxxxxxxxxxxxx)
```
* Verify from master node:
```
# kubectl get nodes
NAME               STATUS   ROLES                  AGE     VERSION
c06-diy-master     Ready    control-plane,master   6d18h   v1.23.3
c06-diy-worker01   Ready    <none>                 7m26s   v1.23.3
c06-diy-worker02   Ready    <none>                 7m19s   v1.23.3

# kubectl get pod -A
NAMESPACE          NAME                                       READY   STATUS    RESTARTS      AGE
calico-apiserver   calico-apiserver-65c659c666-nxcmp          1/1     Running   1 (11h ago)   11h
calico-apiserver   calico-apiserver-65c659c666-v62dk          1/1     Running   1 (11h ago)   11h
calico-system      calico-kube-controllers-77c48f5f64-csl2v   1/1     Running   1 (11h ago)   11h
calico-system      calico-node-6dhcm                          1/1     Running   0             7m57s
calico-system      calico-node-fprb6                          1/1     Running   3 (31m ago)   11h
calico-system      calico-node-zqc59                          1/1     Running   0             8m4s
calico-system      calico-typha-77b7886f75-t5v52              1/1     Running   3 (31m ago)   11h
calico-system      calico-typha-77b7886f75-vkvqv              1/1     Running   0             7m54s
kube-system        coredns-64897985d-2gpp2                    1/1     Running   1 (11h ago)   6d18h
kube-system        coredns-64897985d-tsxcv                    1/1     Running   1 (11h ago)   6d18h
kube-system        etcd-c06-diy-master                        1/1     Running   4 (35m ago)   6d18h
kube-system        kube-apiserver-c06-diy-master              1/1     Running   5 (35m ago)   6d18h
kube-system        kube-controller-manager-c06-diy-master     1/1     Running   4 (35m ago)   6d18h
kube-system        kube-proxy-7gff2                           1/1     Running   4 (35m ago)   6d18h
kube-system        kube-proxy-cqxz4                           1/1     Running   0             8m4s
kube-system        kube-proxy-h7jp8                           1/1     Running   0             7m57s
kube-system        kube-scheduler-c06-diy-master              1/1     Running   4 (35m ago)   6d18h
tigera-operator    tigera-operator-59fc55759-47hv4            1/1     Running   2 (35m ago)   11h
```


