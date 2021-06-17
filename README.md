# Deploy Micro Service on Self-Hosted Knative on AWS EKS

![](https://i.imgur.com/cpv72T3.jpg)
![](https://i.imgur.com/kme8gFM.png)

## Table of Contents

- [Setup Local CLI](#setup-local-cli)
- [Deploy K8S Cluster](#deploy-k8s-cluster)
- [Install Knative in Your EKS Cluster](#install-knative-in-your-eks-cluster)
- [Deploy Service on Knative](#deploy-service-on-knative)
- [Addtional Deploy with Triggermesh](#addtional-deploy-with-triggermesh)
- [Load Testing](#load-testing)
- [Reference](#reference)

## Setup local cli

we need

- aws cli
- eksctl
- kubectl
- (Optional) tm (triggermesh cli)

You can use `Dockerfile` in this repository:

### Build

```bash
docker build . -t triggermesh-cli
```

### run

#### v2 (without aws key)

```bash
docker run --rm --name triggermesh-cli -it      \
           triggermesh-cli
docker exec -it triggermesh-cli bash

mkdir ~/.aws
cat > ~/.aws/credentials

```

#### (old)

```bash
docker run --rm --name triggermesh-cli -it      \
           -e 'AWS_ACCESS_KEY_ID=...'                   \
           -e 'AWS_SECRET_ACCESS_KEY=...'               \
           -e 'AWS_DEFAULT_REGION=ap-northeast-3'                  \
           triggermesh-cli
```

```sh
docker cp ./cluster.yaml triggermesh-cli:/project/cluster.yaml
export ACCOUNT_ID=$(aws sts get-caller-identity -–query "Account" -–output text)
```

## Deploy K8s Cluster

Here we create cluster in region `us-east-1` and create `nodeGroups` of 3 `m5.large` ec2 instanceType

### Option1: Using eksctl and Yaml config (not work in edu)

config is in `./cluster.yaml`

```bash
aws ec2 create-key-pair --region us-east-1 --key-name myKeyPair


# docker cp ./cluster.yaml triggermesh-cli:/project/cluster.yaml
eksctl create cluster --kubeconfig eksknative.yaml \
                      --ssh-public-key myKeyPair \
                      -f cluster.yaml
```

```bash
alias knative='kubectl --kubeconfig=eksknative.yaml'
```

### Option2: Using console and AWS CLI

#### Create an Amazon VPC

```bash
aws cloudformation create-stack \
  --region us-east-1 \
  --stack-name my-eks-vpc-stack \
  --template-url https://s3.us-west-2.amazonaws.com/amazon-eks/cloudformation/2020-10-29/amazon-eks-vpc-private-subnets.yaml
```

#### Create a cluster IAM role

```bash
docker cp ./cluster-role-trust-policy.json triggermesh-cli:/project/cluster-role-trust-policy.json

aws iam create-role \
  --role-name myAmazonEKSClusterRole \
  --assume-role-policy-document file://"cluster-role-trust-policy.json"

aws iam attach-role-policy \
  --policy-arn arn:aws:iam::aws:policy/AmazonEKSClusterPolicy \
  --role-name myAmazonEKSClusterRole
```

#### Create cluster

![](https://i.imgur.com/DerPVvm.png)

![](https://i.imgur.com/ScxHQv6.png)

#### Create nodeGroups

![](https://i.imgur.com/8ZyXJe6.png)

need to set up role for nodeGroups

##### Option 1: console

https://docs.aws.amazon.com/eks/latest/userguide/create-node-role.html

##### Option 2: cli (not work in edu)

```bash
export ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)

# docker cp ./cni-role-trust-policy.json triggermesh-cli:/project/cni-role-trust-policy.json

aws iam create-role \
  --role-name myAmazonEKSCNIRole \
  --assume-role-policy-document file://"cni-role-trust-policy.json"

aws iam attach-role-policy \
  --policy-arn arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy \
  --role-name myAmazonEKSCNIRole

aws eks update-addon \
  --cluster-name my-cluster \
  --addon-name vpc-cni \
  --service-account-role-arn arn:aws:iam::<111122223333>:role/myAmazonEKSCNIRole

# docker cp ./cni-role-trust-policy.json triggermesh-cli:/project/cni-role-trust-policy.json

aws iam create-role \
  --role-name myAmazonEKSNodeRole \
  --assume-role-policy-document file://"node-role-trust-policy.json"

aws iam attach-role-policy \
  --policy-arn arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy \
  --role-name myAmazonEKSNodeRole
aws iam attach-role-policy \
  --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly \
  --role-name myAmazonEKSNodeRole
```

### set up config for `kubectl`

```bash
aws eks --region us-east-1 update-kubeconfig --name knative
kubectl get svc
alias knative='kubectl --kubeconfig=/root/.kube/config'
# eksctl create nodegroup -f ./cluster.yaml
```

### Verify

knative get nodes

## Install Knative in Your EKS cluster

need to install:

- Knative Serving for serving services
- Istio as network layer
- Magic DNS (sslip.io) as free and simple DNS

### Install Knative Serving

```bash
knative apply -f https://github.com/knative/serving/releases/download/v0.23.0/serving-crds.yaml
knative apply -f https://github.com/knative/serving/releases/download/v0.23.0/serving-core.yaml
```

### Install Istio

```bash
knative apply -f https://github.com/knative/net-istio/releases/download/v0.23.0/istio.yaml
knative apply -f https://github.com/knative/net-istio/releases/download/v0.23.0/net-istio.yaml
```

### Fetch the External IP or CNAME:

```bash
knative --namespace istio-system get service istio-ingressgateway
```

### Verify Knative Serving, Istio

```bash
knative get pods --namespace knative-serving
knative get pods --namespace istio-system
```

### Configure DNS

```bash
knative apply -f https://github.com/knative/serving/releases/download/v0.23.0/serving-default-domain.yaml
# knative delete -f https://github.com/knative/serving/releases/download/v0.23.0/serving-default-domain.yaml
```

## Deploy service on Knative

### Monolith autoscale Covid Tracker

service config is in `./service.yaml`

we set `autoscaling.knative.dev/target` to 3, keeping others default. (default is 100)

```bash
# TODO: Prepare env in service.yaml
# rm ./service.yaml
# docker cp ./service.yaml triggermesh-cli:/project/service.yaml
knative apply --filename ./service.yaml
knative get ksvc autoscale-covid-tracker
# http://autoscale-covid-tracker.default.3.224.156.234.sslip.io
# knative get ksvc
watch -n 1 kubectl get pods

knative delete --filename service.yaml
```

### Micro-service Covid Tracker

```bash
# TODO: Prepare env in service.yaml
# docker cp ./service-routing.yaml triggermesh-cli:/project/service-routing.yaml
# docker cp ./routing.yaml triggermesh-cli:/project/routing.yaml
knative apply --filename ./service-routing.yaml
knative apply --filename ./routing.yaml
knative get ksvc
```

#### Routing

![](https://i.imgur.com/kme8gFM.png)

```bash
kubectl get route user-service  --output=custom-columns=NAME:.metadata.name,URL:.status.url

export GATEWAY_IP=3.224.156.234
export GATEWAY_HOSTNAME=3.224.156.234.sslip.io
curl http://${GATEWAY_IP} --header "Host:autoscale-covid-tracker.default.3.224.156.234.sslip.io"
curl http://${GATEWAY_HOSTNAME} --header "Host:autoscale-covid-tracker.default.3.224.156.234.sslip.io"
curl http://${GATEWAY_HOSTNAME} --header "Host:user-service.default.${GATEWAY_HOSTNAME}"

curl http://${GATEWAY_IP}/record --header "Host: ${GATEWAY_HOSTNAME}"
curl http://${GATEWAY_HOSTNAME}/record
```

### Uninstall

```bash
knative delete --filename service.yaml

knative delete -f https://github.com/knative/net-istio/releases/download/v0.23.0/net-istio.yaml
knative delete -f https://github.com/knative/net-istio/releases/download/v0.23.0/istio.yaml

```

## Addtional: Deploy with TriggerMesh

### Install the TriggerMesh CLI tm

...in Dockerfile

#### Verify TriggerMesh tm

```bash
which tm
```

```bash
alias tmk='tm --config=eksknative.yaml'
```

#### Verify

```bash
tmk get services
```

### Deploy a Function with the Knative Lambda Runtime (KLR)

### Deploy function using Go Knative lambda runtime

### https://github.com/triggermesh/tm

```bash
tmk deploy service go-lambda -f . --runtime https://raw.githubusercontent.com/triggermesh/knative-lambda-runtime/master/go/runtime.yaml --wait
tmk deploy service go-lambda -f ./lambda/. --runtime https://raw.githubusercontent.com/triggermesh/knative-lambda-runtime/master/go/runtime.yaml --wait
```

### Docker

```bash
tmk deploy service foo -f gcr.io/google-samples/hello-app:1.0 --wait
```

tm deploy service covid-tracker \
 -f hwww1116/covid-tracker \
 -e 'SERVICE=all' \
 -e 'AWS_ACCESS_KEY_ID=ASIAR24YQQ5GDTMCXDQT' \
 -e 'AWS_SECRET_ACCESS_KEY=iA8SP4x5YvLfpa4p+DuvE0VdSGVlWtAyjBb/Vxs1' \
 -e 'AWS_SESSION_TOKEN=FwoGZXIvYXdzEHoaDIMMm02paxyHtCKB0CLEASY/NLXUkg2/E5XFscFQe1StciE5idW25AIvCwhTQz7v/fs5i34vFR+2BFnrn+KAW8y5SrawfDG0SPytZZiG7BbunLehGDCjZT6BzpkmQ2GL0J+AtakCJROeln+011WCCoraEBTxNviJchsDeIsWOyGJwdIugECs/i+9/slVBMY0vo7FU9veQFV24UsfYFRrzFCzysGGhZM0vsRIj7PSd/MaZAZALxQ1afIWr1JiSNeQOCWYiwHRKSe5Im27ii0vCNIWPQIo67KjhgYyLQJBTpKun0CjskYyd513Tm+FuHP1u0us004qafF5l530uhb6XMhN02VjhGrvYw==' \
 --wait

tm deploy service covid-tracker-store \
 -f hwww1116/covid-tracker-store \
 -e foo=bar \
 --wait

### Others

tm deploy -f https://github.com/tzununbekov/serverless

tm deploy -f ./serverless.yaml

https://github.com/tzununbekov/serverless

### On triggermesh Cloud

```sh
mkdir secrets
docker cp ./secrets/tmconfig.json triggermesh-cli:/project/secrets/tmconfig.json
mkdir $HOME/.tm
mv ./secrets/tmconfig.json $HOME/.tm/config.json
```

## Load testing

### Test example

```sh
export ROOT=http://localhost:8888
curl -X POST $ROOT/auth/user/signup -d '{"phone": "0912345678", "password": "878787"}'
curl -X POST $ROOT/auth/user/login -d '{"phone": "0912345678", "password": "878787"}'
curl -X POST $ROOT/auth/store/signup -d '{"phone": "0987654321", "password": "87878787", "name": "giver", "address": "taiwan"}'
curl -X POST $ROOT/auth/store/login -d '{"phone": "0987654321", "password": "87878787"}'
curl -X GET $ROOT/auth/store/profile -H 'Authorization: Bearer <store's jwt token>'
curl -X POST $ROOT/records -H 'Authorization: Bearer <user's jwt token>' -d '{"store_id": "0987654321"}'
```

### Hey

https://knative.dev/docs/serving/autoscaling/autoscale-go/

```bash
export ROOT=http://3.224.156.234.sslip.io

curl -X POST $ROOT/auth/user/signup -d '{"phone": "0912345678", "password": "0912345678"}'
curl -X POST $ROOT/auth/store/signup -d '{"phone": "0987654321", "password": "0912345678", "name": "giver", "address": "taiwan"}'

export STORE_TOKEN=$(curl -X POST $ROOT/auth/store/login -d '{"phone": "0987654321", "password": "87878787"}' | sed 's/{"token":"\([^"]*\)"}/\1/')

curl -X GET $ROOT/auth/store/profile -H "Authorization: Bearer $STORE_TOKEN"

export QRCODE=$(curl -X GET $ROOT/auth/store/profile -H "Authorization: Bearer $STORE_TOKEN" | jq '.qrcode' )

export TOKEN=$(curl -X POST $ROOT/auth/user/login -d '{"phone": "0912345678", "password": "878787"}' | sed 's/{"token":"\([^"]*\)"}/\1/')

curl \
  -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -d "{\"store_id\": $QRCODE }" \
  "$ROOT/records"
```

### User

```bash
go get -u github.com/rakyll/hey
```

Send 30 seconds of traffic maintaining 50 in-flight requests.

```sh
knative get pods

hey -z 30s -c 50 \
  -m POST \
  -H "Authorization: Bearer $TOKEN" \
  -d "{\"store_id\": $QRCODE }" \
  "$ROOT/records"

knative get pods
```

### Store

hey -z 30s -c 50 \
 "https://tm-demo-go-openfaas.z0916945857.k.triggermesh.io/" \
 && tm get services


## Reference

https://eksctl.io/usage/minimum-iam-policies/
https://knative.dev/docs/install/install-serving-with-yaml/
https://docs.triggermesh.io/tm/usage/
https://github.com/triggermesh/tm
https://github.com/triggermesh/knative-lambda-runtime