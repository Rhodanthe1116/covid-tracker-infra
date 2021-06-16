docker cp ./cluster.yaml triggermesh-cli:cluster.yaml 
export ACCOUNT_ID=$(aws sts get-caller-identity –query "Account" –output text)
# Deploy Cluster
eksctl create cluster --kubeconfig eksknative.yaml -f cluster.yaml

alias knative='kubectl --kubeconfig=eksknative.yaml'
## Verify
knative get nodes

# Install Knative in Your EKS cluster

## Install Knative Serving
knative apply -f https://github.com/knative/serving/releases/download/v0.23.0/serving-crds.yaml
knative apply -f https://github.com/knative/serving/releases/download/v0.23.0/serving-core.yaml

## Install Istio
knative apply -f https://github.com/knative/net-istio/releases/download/v0.23.0/istio.yaml
knative apply -f https://github.com/knative/net-istio/releases/download/v0.23.0/net-istio.yaml

### Fetch the External IP or CNAME:
knative --namespace istio-system get service istio-ingressgateway

## Verify
knative get pods --namespace knative-serving

## Configure DNS 
knative apply -f https://github.com/knative/serving/releases/download/v0.23.0/serving-default-domain.yaml

# Install the TriggerMesh CLI tm
curl -L https://github.com/triggermesh/tm/releases/download/v1.6.0/tm-linux-amd64 --output tm-linux-amd64
mv tm-linux-amd64 /usr/local/bin/tm
chmod +x /usr/local/bin/tm
## Verify
which tm

alias tmk='tm --config=eksknative.yaml'

## Verify
tmk get services

# Deploy a Function with the Knative Lambda Runtime (KLR)

# Deploy function using Go Knative lambda runtime
# https://github.com/triggermesh/tm
tmk deploy service go-lambda -f . --runtime https://raw.githubusercontent.com/triggermesh/knative-lambda-runtime/master/go/runtime.yaml --wait
tmk deploy service go-lambda -f ./lambda/. --runtime https://raw.githubusercontent.com/triggermesh/knative-lambda-runtime/master/go/runtime.yaml --wait
