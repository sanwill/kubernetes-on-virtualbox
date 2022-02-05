# Install Kubernetes on VirtualBox VMs

## Overview
This following steps cover the steps required to create a Kubernetes Lab on VirtualBox VMs.
The steps to install VirtualBox, detail steps on how to create the VirtualBox VM and Guest OS installation are not covered.
The VM OS will use Ubuntu-server 18.04 LTS.  


## Preparation
* Install VirtualBOx on PC/Mac
* Create host-only network on VirtualBox, for example: **vboxnet0** use IPv4 network address 192.168.70.1 and subnet 24
* Create **3 VMs** with 2 vCPU, 4096GB RAM each (for lower spec system, you can cut the spec to half), 100GB storage. This VM will be named as:
  * master-node
  * worker01-node
  * worker02-node.
* Attach 2 network interfaces on every VM:
  * NIC #1 usses bridge adapter, will be used for external connectivity
  * NIC #2 usses host-only  **vboxnet0**, will be used for internal connectivity
* Attach the Ubuntu-server ISO to each VM  
  
Reference: [Setup VM](https://docs.oracle.com/cd/E26217_01/E26796/html/qs-create-vm.html)

# Install OS
## OS Installation
Boot the VM to Ubuntu-server ISO
* Opt to install the openssh-server at the installation screen
* Set the user name and password
* Set the hostname according to the VM designated usage, for example: master-node
* Do not add any additonal packages
* Let the rest to default

Proceed with Ubuntu-server OS installation.  
  
Reference: [Ubuntu installation](https://ubuntu.com/tutorials/install-ubuntu-server#1-overview)

## Post OS Installation
Once the installation is finished login to each VM console using the user name and password created earlier.
* Configure the hostname:
```console
sudo hostnamectl set-hostname <hostname>
```
For example

```console
sudo hostnamectl set-hostname master-node
```

* Configure static IP address
```console
vi /etc/netplan/01-netcfg.yaml
```
```shell
network:
  version: 2
  renderer: networkd
  ethernets:
    enp0s3:
      dhcp4: no
      addresses:
        - 192.168.0.10/24
      gateway4: 192.168.0.1
      nameservers:
          addresses: [8.8.8.8, 1.1.1.1]        
    enp0s8:
      dhcp4: no
      addresses:
        - 192.168.70.3/24
      gateway4: 192.168.70.1
```  

**Note:**  
enp0s3 is NIC #1 the interface toward the bridge adapter  
enp0s8 is NIC #2 the interface toward the host-only network vboxnet0  
The external network is 192.168.0.0/24 and the static IP for external communication for this VM is 192.168.0.10  
The internal network is 192.168.70.0/24 and the static IP for internal communication for this VM is 192.168.70.3  

Next, apply the static IP configuration
```console
sudo netplan apply
```

Ensure that there is only 1 default route on VM. If there is any additionaly default route, remove the wrong default route.
For example:
```console
$ ip r
default via 192.168.0.1 dev enp0s3 proto static
default via 192.168.70.1 dev enp0s8 proto static <--- not needed, remove it
...
...

$ sudo ip r delete default via 192.168.70.1 dev enp0s8 proto static
```
* Login to VM using its IP and credential to test if SSH connection work.
* Repeat the steps to all VM.

# Kubernetes Cluster Installation
## Installing kubeadm 
We will follow the steps in [Installing kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/) from [kubernetes.io documentation](https://kubernetes.io/docs/home/).

The installation consist of 3 parts which need to be run on **all nodes, master and worker nodes**.
* [Iptables setup](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/#letting-iptables-see-bridged-traffic)
* [Install CRI/Container Runtime](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/#installing-runtime)
  * This is to install container SW such as Docker Engine, containerd etc
* [Installing kubeadm, kubelet and kubectl](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/#installing-kubeadm-kubelet-and-kubectl)

Once you finished those 3 steps, the kubelet will restarting every few seconds, as it waits in a crashloop for kubeadm to tell it what to do. Next step will be to initiate cluster using kubeadm.

I have created a simple shell to automate the steps, no validation check etc. See [k8s_install_ubuntu_allnodes.sh](scripts/k8s_install_ubuntu_allnodes.sh).  
This script uses Docker Engine as container runtime.  
To execute the script, copy the script to all nodes and execute using sudo:
```console
sudo sh k8s_install_ubuntu_allnodes.sh
```

## Initializing Control-plane/Master Node
We will follow instructions in [Creating a cluster with kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/) to intiate master node.  

* Execute kubeadm init command on master node as root user and note down the "kubeadm join" command in the output file
```console
sudo kubeadm init --pod-network-cidr 10.211.0.0/16 --apiserver-advertise-address=192.168.70.3
```
Output:  
```shell
[init] Using Kubernetes version: v1.23.3
...
...

Your Kubernetes control-plane has initialized successfully!

To start using your cluster, you need to run the following as a regular user:

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

Alternatively, if you are the root user, you can run:

  export KUBECONFIG=/etc/kubernetes/admin.conf

You should now deploy a pod network to the cluster.
Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
  https://kubernetes.io/docs/concepts/cluster-administration/addons/

Then you can join any number of worker nodes by running the following on each as root:

kubeadm join 192.168.70.3:6443 --token ul3z4n.znd6xxxxxxxxxxxx \
        --discovery-token-ca-cert-hash sha256:xxxxxxxxxd6fde0f1e27e5bbb3d873f316a7d065fb5fe57517xxxxxxxxxxxxxxx
```
**Note**  
10.211.0.0/16 is the POD network CIDR. You can select whichever network address that fit your requirement.  
192.168.70.3 is the host-only vboxnet0 network  


* Copy the config Kube directory/file.  
```console
mkdir -p $HOME/.kube;   sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config;   sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

* Next, install the Weave network CNI so that the created POD can use POD network.
```console
kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')"
```

* Install etcdctl-client package.  
```console
sudo install etcd-client -y
````

## Join the worker node to Control-plane/Master Node
SSH to each worker node and run the join command:

```console
kubeadm join 192.168.70.3:6443 --token ul3z4n.znd6xxxxxxxxxxxx \
        --discovery-token-ca-cert-hash sha256:xxxxxxxxxd6fde0f1e27e5bbb3d873f316a7d065fb5fe57517xxxxxxxxxxxxxxx)
```


**Note:**  
The join command was printed out at the kubeadm init output.  If you missed or loss the session, you can ask kubeadm to reprint the join command by running this command on master node:
```console
kubeadm token create --print-join-command
```

# Verify The Kubernetes Cluster
Login to master node.
Execute these following commands.

```console
kubectl get nodes
```
Expected output: all nodes are in **Ready** state

```console
kubectl get pod -n kube-sytem
```
Expected output: all kube-system pods are in **Running** state

Create a test pod, for example:
```console
$ kubectl run nginx --image=nginx
pod/nginx created

$ kubectl get pod nginx
NAME    READY   STATUS    RESTARTS   AGE
nginx   1/1     Running   0          37s
```
Expected output: The test pod nginx is in **Running** state.





