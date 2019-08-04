# Install 3 node k8s cluster using KOPS.
- Create EC2 instance for kubectl.
- Create ec2-admin role and attach Administrator policy.
- Create a hosted zone in AWS (vinga.cf)
- Login to kubectl server and run below commands
```
$ aws s3api create-bucket --bucket vinga.cf --region ap-south-1
- Install kubectl:
$ curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
$ chmod +x ./kubectl
$ sudo mv ./kubectl /usr/local/bin/kubectl
$ apt-get install python
$ pip install aws-cli
$ ssh-keygen -f .ssh/id_rsa
- Install KOPS:
$ wget https://github.com/kubernetes/kops/releases/download/$(curl -s https://api.github.com/repos/kubernetes/kops/releases/latest | grep tag_name | cut -d '"' -f 4)/kops-linux-amd64
$ chmod +x kops-linux-amd64
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






