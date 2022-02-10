# Install Kubernetes on VirtualBox VMs

## Overview
This following steps cover the steps required to create a Kubernetes Lab on VirtualBox VMs.
The steps to install VirtualBox, detail steps on how to create the VirtualBox VM and Guest OS installation are not covered.
The VM OS will use Ubuntu-server 18.04 LTS.  
**You may change the network or IP addresses as per your network plan.**


## Preparation
* Install VirtualBOx on PC/Mac
* Create host-only network on VirtualBox, for example: **vboxnet0** use IPv4 network address 192.168.70.0 (GW address: 192.168.70.1) and subnet 24 (Netmask: 255.255.255.0)
* Create **3 VMs** with 2 vCPU, 4096GB RAM each (for lower spec system, you can cut the spec to half), 100GB storage. These VMs will be named as:
  * master-node
  * worker01-node
  * worker02-node.
* Attach 2 network interfaces on every VM:
  * NIC #1 usses bridge adapter, will be used for external connectivity. In this instruction, it is assumed that the external network is using network adress: 192.168.0.0/24. Where master-node will have static IP 192.168.0.10, worker01 will use 192.168.0.11 and worker02 will use 192.168.0.12.
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
```
# sudo hostnamectl set-hostname <hostname>
```
For example

```
# sudo hostnamectl set-hostname master-node
```
Note:
**If you have setup the hostname during installation, you may skip the above step**

* Configure static IP address
```
# vi /etc/netplan/01-netcfg.yaml
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
Change the addresses as per your network plan.  
enp0s3 is NIC #1 the interface toward the bridge adapter.  
enp0s8 is NIC #2 the interface toward the host-only network vboxnet0.  
The external network is 192.168.0.0/24 and the static IP for external communication for this VM is 192.168.0.10.  
The internal network is 192.168.70.0/24 and the static IP for internal communication for this VM is 192.168.70.3.  

Next, apply the static IP configuration
```
# sudo netplan apply
```

Ensure that there is only 1 default route on VM. If there is any additionaly default route, remove the wrong default route.
For example:
```
# ip r
default via 192.168.0.1 dev enp0s3 proto static
default via 192.168.70.1 dev enp0s8 proto static <--- not needed, remove it
...
...

# sudo ip r delete default via 192.168.70.1 dev enp0s8 proto static
```

Add this following service to remove the duplicated default route after reboot.

```
# sudo cat <<EOF | sudo tee /etc/systemd/system/cleanup-double-route.service
[Unit]
Description=Custom script, remove double default route on Ubuntu

[Service]
User=root
ExecStart=/bin/bash -c "ip route delete default via 192.168.70.1 dev enp0s8 proto static"

[Install]
WantedBy=multi-user.target
EOF
```

Start and enable the service.
```
# sudo system4ctl daemon-reload
# sudo systemctl restart cleanup-double-route.service
# sudo systemctl enable cleanup-double-route.service
```

* Login to VM using its IP and credential to test if SSH connection work.
* Repeat the steps to all VM but change the hostname and the IP addresses.
  
# Kubernetes Cluster Installation
## Installing kubeadm 
We will follow the steps in [Installing kubeadm page](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/) from [kubernetes.io documentation](https://kubernetes.io/docs/home/).

The installation consist of 3 parts which need to be run on **all nodes, master and worker nodes**.
* [Iptables setup](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/#letting-iptables-see-bridged-traffic)
* [Install CRI/Container Runtime](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/#installing-runtime)
  * This is to install container SW such as Docker Engine, containerd etc
* [Installing kubeadm, kubelet and kubectl](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/#installing-kubeadm-kubelet-and-kubectl)

Once you finished those 3 steps, the kubelet will restarting every few seconds, as it waits in a crashloop for kubeadm to tell it what to do. Next step will be to initiate cluster using kubeadm.

I have created a simple shell script to automate the steps, no validation check etc. See [k8s_install_ubuntu_allnodes.sh](scripts/k8s_install_ubuntu_allnodes.sh).  
This script uses Docker Engine as container runtime.  
To execute the script, copy the script to all nodes and execute using sudo:
```
# sudo sh k8s_install_ubuntu_allnodes.sh
```

## Initializing Control-plane/Master Node
We will follow instructions in [Creating a cluster with kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/) to intiate master node.  

* Execute kubeadm init command on master node as root user and note down the "kubeadm join" command in the output file
```
# sudo kubeadm init --pod-network-cidr 10.211.0.0/16 --apiserver-advertise-address=192.168.70.3
```
Output:  
```
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
192.168.70.3 is the IP address of master node running on host-only vboxnet0 network. This IP was set at [post-installation step](https://github.com/sanwill/kubernetes-on-virtualbox/edit/main/README.md#post-os-installation).


* Copy the config Kube directory/file.  
```
# mkdir -p $HOME/.kube;   sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config;   sudo chown $(id -u):$(id -g) $HOME/.kube/config
```
* Install etcdctl-client package.  
```
# sudo install etcd-client -y
````

## Install Network CNI

* Next, install the Weave network CNI so that the created POD can use POD network.
```
# kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')"
```

Note:  
* You can opt to install different network CNI. See [Cluster Networking](https://kubernetes.io/docs/concepts/cluster-administration/networking/) for more details. 
* At [cluster-network page](https://github.com/sanwill/kubernetes-on-virtualbox/tree/main/cluster-network), I shared steps to install calico and multus CNI.  
  * If you wish to [install Calico CNI](https://github.com/sanwill/kubernetes-on-virtualbox/blob/main/cluster-network/install-calico.md) instead of weave CNI.
  * If you wish to [install Multus CNI](https://github.com/sanwill/kubernetes-on-virtualbox/blob/main/cluster-network/install-multus.md) to enable multiple interface on the POD.



## Join the worker node to Control-plane/Master Node
SSH to each worker node and run the join command:

```
# kubeadm join 192.168.70.3:6443 --token ul3z4n.znd6xxxxxxxxxxxx \
        --discovery-token-ca-cert-hash sha256:xxxxxxxxxd6fde0f1e27e5bbb3d873f316a7d065fb5fe57517xxxxxxxxxxxxxxx)
```


**Note:**  
The join command was printed out at the kubeadm init output.  If you missed or loss the session, you can ask kubeadm to reprint the join command by running this command on master node:
```
# kubeadm token create --print-join-command
```

# Verify The Kubernetes Cluster
Login to master node.
Execute these following commands.

```
# kubectl get nodes
```
Expected output: all nodes are in **Ready** state

```
# kubectl get pod -n kube-sytem
```
Expected output: all kube-system pods are in **Running** state

Create a test pod, for example:
```
# kubectl run nginx --image=nginx
pod/nginx created

# kubectl get pod nginx
NAME    READY   STATUS    RESTARTS   AGE
nginx   1/1     Running   0          37s
```
Expected output: The test pod nginx is in **Running** state.





