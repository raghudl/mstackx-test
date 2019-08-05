# Solution

## Install Kubernetes.

1. HA k8s cluster via Terraform and Ansible.
2. K8s installation via KOPS.

### HA k8s cluster via Terraform and Ansible.
- Please refer below readme.
- k8s-cluster-terraform-ansible/README.md

### K8s installation via KOPS.

#### Assumptions
- I have tested the mediawiki deployment on above HA k8s cluster 
- but it was expensive for me to keep running hence I am demonstrating the same on KOPS.
- KOPS_CLUSTER_NAME=vinga.cf (When you run it, change the name)
- KOPS_STATE_STORE=s3://vinga.cf (When you run it, change the name)
- Kubectl running on ubuntu 16.04 box.
- Created a hosted zone in AWS (vinga.cf) (When you run it, change the name)

#### Make Kubectl machine ready.
- Create EC2 instance of ubuntu 16.04.
- Create ec2-admin role and attach Administrator policy.(We can make our policy and attach)
- Login to kubectl server and run below commands
- Install kubectl:
```
$ curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
$ chmod +x ./kubectl
$ sudo mv ./kubectl /usr/local/bin/kubectl
$ apt-get install python
$ pip install aws-cli
$ aws s3api create-bucket --bucket vinga.cf --region ap-south-1
$ ssh-keygen -f .ssh/id_rsa
```
- Install Helm.
```
$ wget https://get.helm.sh/helm-v2.14.3-linux-amd64.tar.gz
$ tar -zxvf helm-v2.14.3-linux-amd64.tar.gz
$ mv linux-amd64/helm /usr/local/bin/helm

```
- Install KOPS:
```
$ wget https://github.com/kubernetes/kops/releases/download/$(curl -s https://api.github.com/repos/kubernetes/kops/releases/latest | grep tag_name | cut -d '"' -f 4)/kops-linux-amd64
$ sudo chmod +x kops-linux-amd64
$ sudo mv kops-linux-amd64 /usr/local/bin/kops
$ export KOPS_STATE_STORE=s3://vinga.cf
$ export KOPS_CLUSTER_NAME=vinga.cf
$ kops create cluster --cloud=aws --zones=ap-south-1a,ap-south-1b --name vinga.cf --node-count=2 --node-size=t2.medium --master-size=t2.micro
$ kops update cluster --name ${KOPS_CLUSTER_NAME} –yes
$ kops validate cluster

```
## Install nginx-controller
```
$ kubectl create -f nginx-controller/nginx.yaml
$ kubectl create -f nginx-controller/nginx-controller-service.yaml
$ kubectl create -f https://raw.githubusercontent.com/kubernetes/contrib/master/ingress/controllers/nginx/examples/default-backend.yaml
$ kubectl expose rc default-http-backend --port=80 --target-port=8080 --name=default-http-backend
$ kubectl create -f ingress.yaml
```
## DNS hosts are made in ingress.yaml for 2 urls.(Read ingress.yaml)
- Get ingress-nginx Loadbalancer url.
```
$ kubectl get svc | grep ingress | awk '{print $4}'
```
- Make A records for below domains with above LB url.
- mediawiki.vinga.cf
- jenkins.vinga.cf

## Install helm
```
$ kubectl create -f helm-rbac.yaml
$ helm init --service-account tiller --upgrade
```
## Custom repository for helm charts.
```
$ sh helm-s3.sh (This will create a random bucket helm-XXXXX)
- Set the bucket permission for newly created bucket.
$ put-bucket-policy.sh
```
## Install Jenkins via helm charts.
```
$ helm install --name jenkins jenkins/
- Get Jenkins password from below command.
$ printf $(kubectl get secret --namespace default jenkins -o jsonpath="{.data.jenkins-admin-password}" | base64 --decode);echo
```
- Login to Jenkins via below url.
```
http://jenkins.vinga.cf
```
### Configure Jenkins pipeline job.
- Build
- Deploy
#### build steps:
- Create Service Account for Jenkins.
```
$ kubectl create -f jenkins-serviceaccount.yaml
$ cat Jenkinsfile.build
```
- Create pipeline job and paste above content.
- Make required changes like BucketName=helm-XXXX
- Save the job and run.
- This will build the charts and upload to s3.

#### deploy steps:
- Create Service Account for Jenkins.
```
$ cat Jenkinsfile.deploy
```
- Create pipeline job and paste above content.
- Make required changes like BucketName=helm-XXXX
- Save the job and run.
- This will download the chart from s3 and run the deployment for mediawiki.
## Kubernetes Dashboard.
```
$ kubectl create -f https://raw.githubusercontent.com/kubernetes/kops/master/addons/kubernetes-dashboard/v1.8.3.yaml 
$ kubectl create -f kube-dashboard-access.yaml
```
- Get the Token to login.
```
$ kubectl get secret --namespace kube-system $(kubectl get serviceaccount --namespace kube-system kubernetes-dashboard -o jsonpath="{.secrets[0].name}") -o jsonpath="{.data.token}" | base64 --decode
```
- Get the link to connect Daskboard.
```
$ kubectl cluster-info | grep master 
```
- Once you get the url, append this link /api/v1/namespaces/kube-system/services/https:kubernetes-dashboard:/proxy/
- Example.
- https://api.vinga.cf/api/v1/namespaces/kube-system/services/https:kubernetes-dashboard:/proxy/
- Enter the token which you received from above command.


## Create Docker private repositry.
- Install certificate manager
```
kubectl apply \
    -f https://raw.githubusercontent.com/jetstack/cert-manager/release-0.8/deploy/manifests/00-crds.yaml
```
- You should see the following output:
```
customresourcedefinition.apiextensions.k8s.io/certificates.certmanager.k8s.io created
customresourcedefinition.apiextensions.k8s.io/issuers.certmanager.k8s.io created
customresourcedefinition.apiextensions.k8s.io/clusterissuers.certmanager.k8s.io created
customresourcedefinition.apiextensions.k8s.io/orders.certmanager.k8s.io created
customresourcedefinition.apiextensions.k8s.io/challenges.certmanager.k8s.io created
```
- Label the kube-system namespace.
```
kubectl label namespace kube-system certmanager.k8s.io/disable-validation="true"
```
- Add the Jetstack Helm repository to Helm. This repository contains the cert-manager Helm chart.
```
helm repo add jetstack https://charts.jetstack.io
```
- Install the chart into the kube-system namespace:
```
helm install --name cert-manager --namespace kube-system jetstack/cert-manager --version v0.8.0
- You should see following message.
```
Output
. . .
NOTES:
cert-manager has been deployed successfully!

In order to begin issuing certificates, you will need to set up a ClusterIssuer
or Issuer resource (for example, by creating a 'letsencrypt-staging' issuer).

More information on the different types of issuers and how to configure them
can be found in our documentation:

https://cert-manager.readthedocs.io/en/latest/reference/issuers.html

For information on how to configure cert-manager to automatically provision
Certificates for Ingress resources, take a look at the `ingress-shim`
documentation:

https://cert-manager.readthedocs.io/en/latest/reference/ingress-shim.html
```

- Roll out the ClusterIssuer using kubectl:

```
kubectl create -f staging_issuer.yaml

```
- Install docker registry 
```
helm install  --name docker-registry docker-registry/
```
- I have created ingress for registry which will be served by nginx controller.
- Create an entry in route 53 for registry.vinga.cf pointing to Nginx controller ELB.
- I have hardcoded the credentials.
- username: vinga
- password: test123
- Try login with above credentials.
```
docker login registry.vinga.cf
```
- Now we need to make sure K8s cluster should know the credentials.
- Run below command on kubectl server.
```
kubectl create secret generic regcred --from-file=.dockerconfigjson=/home/ubuntu/.docker/config.json --type=kubernetes.io/dockerconfigjson
```










