#!/bin/bash

echo -e "\n###############" 
echo      "Set OS - Ubuntu"
echo      "###############"

sudo swapoff -a
sudo sed -i '/\/swap.img/s/^/#/' /etc/fstab

sudo modprobe br_netfilter
lsmod | grep br_netfilter


# Lab only
#systemctl disable firewalld --now 

cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF
sudo sysctl --system


echo -e "\n##############" 
echo -e   "Install containerd"
echo      "##############"

#https://docs.docker.com/engine/install/ubuntu/
sudo apt-get remove docker docker-engine docker.io containerd runc -y
sudo apt-get update -y

sudo apt-get install ca-certificates curl gnupg lsb-release -y

sudo mkdir -p /etc/apt/keyrings

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo chmod a+r /etc/apt/keyrings/docker.gpg

sudo apt-get update -y

sudo apt-get install docker-ce docker-ce-cli containerd.io docker-compose-plugin -y

sudo docker run hello-world

#https://kubernetes.io/docs/setup/production-environment/container-runtimes/#containerd
#Make sure that cri is not included in thedisabled_plugins list
sed -i 's/cri//g' /etc/containerd/config.toml
sudo systemctl restart containerd


echo -e "\n#########################################" 
echo -e   "Install Install Kubeadm, kubelet, kubectl"
echo      "#########################################" 

#Update the apt package index and install packages needed to use the Kubernetes apt repository:

sudo apt-get update -y
sudo apt-get install -y apt-transport-https ca-certificates curl

sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg


echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list


sudo apt-get update -y
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl



#On Master node
# kubeadm init --pod-network-cidr 10.246.0.0/16 --apiserver-advertise-address=192.168.61.3
#  mkdir -p $HOME/.kube;   sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config;   sudo chown $(id -u):$(id -g) $HOME/.kube/config

#Install Weave network CNI
#kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')"

#apt install etcd-client -y


#On worker node
# kubeadm join 192.168.61.3:6443 --token i8i36l.v4am9xluq8mwe4sl --discovery-token-ca-cert-hash sha256:6b9e4027a53be134ca013221c7407e784732d7f9de1fdc03a851bc3971aa6e57 
