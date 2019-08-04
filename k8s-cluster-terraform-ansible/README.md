# Kubernetes cluster creation.
- This steps will help in installing k8s cluster from scratch on AWS using Ansible and Terraform.

Terraform will create below resources:
- AWS VPC
- 3 EC2 instances for HA Kubernetes Control Plane: Kubernetes API, Scheduler and Controller Manager
- 3 EC2 instances for *etcd* cluster.
- 3 EC2 instances as Kubernetes Workers.
- Kubenet Pod networking (using CNI)
- HTTPS between components and control API.

## Requirements

Requirements on control machine:

- Terraform.(Tested on Terraform v0.12.6)
- Python (tested with Python 2.7.12, may be not compatible with older versions; requires Jinja2 2.8)
- Ansible (Tested on Ansible 2.0.0.2)
- *cfssl* and *cfssljson*:  https://github.com/cloudflare/cfssl
- Kubernetes CLI
- SSH Agent
- (optionally) AWS CLI

### Installation steps:
- Install cfssl and cfssljson
```
$ curl https://pkg.cfssl.org/R1.2/cfssl_linux-amd64 -o /usr/local/bin/cfssl
$ curl https://pkg.cfssl.org/R1.2/cfssljson_linux-amd64 -o /usr/local/bin/cfssljson
$ chmod +x /usr/local/bin/cfssl /usr/local/bin/cfssljson
$ git clone https://github.com/vinga2805/mstackx-test.git
$ cd mstackx-test/k8s-cluster-terraform-ansible/terraform
$ ssh-keygen -f k8s
$ cat k8s.pub 
$ vi terraform.tfvars
Add public key against this field default_keypair_public_key
Change control_cidr to your kubectl/terraform server.
$ export AWS_ACCESS_KEY_ID=<access-key-id>
$ export AWS_SECRET_ACCESS_KEY="<secret-key>"
```
### Sample `terraform.tfvars`:
```
default_keypair_public_key = "ssh-rsa AAA...zzz"
control_cidr = "123.45.67.89/32"
default_keypair_name = "k8s"
vpc_name = "k8s-demo"
elb_name = "k8s-elb"
owner = "vishal"
```
```
$ terraform plan
$ terraform apply
```
```
Output:
kubernetes_api_dns_name = kubernetes-1139381945.us-west-2.elb.amazonaws.com
kubernetes_workers_public_ip = 34.220.67.40,34.210.78.65,54.200.30.0
```
### Generated SSH config

Terraform generates `ssh.cfg`, SSH configuration file in the project directory.
It is convenient for manually SSH into machines using node names (`controller0`...`controller2`, `etcd0`...`2`, `worker0`...`2`), but it is NOT used by Ansible.

e.g.
```
$ ssh -F ssh.cfg worker0
```

## Install Kubernetes components with Ansible


### Install and set up Kubernetes cluster

Install Kubernetes components and *etcd* cluster.
```
$ ansible-playbook infra.yaml
```

### Setup Kubernetes CLI

Configure Kubernetes CLI (`kubectl`) on your machine, setting Kubernetes API endpoint (as returned by Terraform).
```
$ ansible-playbook kubectl.yaml --extra-vars "kubernetes_api_endpoint=<kubernetes-api-dns-name>"
```

Verify all components and minions (workers) are up and running, using Kubernetes CLI (`kubectl`).

```
$ kubectl get componentstatuses
NAME                 STATUS    MESSAGE              ERROR
controller-manager   Healthy   ok
scheduler            Healthy   ok
etcd-2               Healthy   {"health": "true"}
etcd-1               Healthy   {"health": "true"}
etcd-0               Healthy   {"health": "true"}

$ kubectl get nodes
NAME                                       STATUS    AGE
ip-10-43-0-30.eu-west-1.compute.internal   Ready     6m
ip-10-43-0-31.eu-west-1.compute.internal   Ready     6m
ip-10-43-0-32.eu-west-1.compute.internal   Ready     6m
```

### Setup Pod cluster routing

Set up additional routes for traffic between Pods.
```
$ ansible-playbook kubernetes-routing.yaml
```

