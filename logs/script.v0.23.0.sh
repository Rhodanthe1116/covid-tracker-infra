docker cp ./cluster.yaml triggermesh-cli:cluster.yaml 
export ACCOUNT_ID=$(aws sts get-caller-identity –query "Account" –output text)
# Deploy Cluster
eksctl create cluster --kubeconfig eksknative.yaml -f cluster.yaml

alias knative='kubectl --kubeconfig=eksknative.yaml'
## Verify
knative get nodes

# Install Knative in Your EKS cluster

## Install Knative Serving and Knative Build
# knative apply --filename https://github.com/knative/serving/releases/download/v0.4.0/serving.yaml \
# --filename https://github.com/knative/build/releases/download/v0.4.0/build.yaml \
# --filename https://github.com/knative/serving/releases/download/v0.4.0/monitoring.yaml \
# --filename https://raw.githubusercontent.com/knative/serving/v0.4.0/third_party/config/build/clusterrole.yaml
knative apply -f https://github.com/knative/serving/releases/download/v0.23.0/serving-crds.yaml
knative apply -f https://github.com/knative/serving/releases/download/v0.23.0/serving-core.yaml

## Install Istio
# knative apply --filename https://github.com/knative/serving/releases/download/v0.4.0/istio-crds.yaml && \
# knative apply --filename https://github.com/knative/serving/releases/download/v0.4.0/istio.yaml
knative apply -f https://github.com/knative/net-istio/releases/download/v0.23.0/istio.yaml
knative apply -f https://github.com/knative/net-istio/releases/download/v0.23.0/net-istio.yaml

### Fetch the External IP or CNAME:
knative --namespace istio-system get service istio-ingressgateway

## Verify
# knative get pods -n knative-serving
# knative get pods -n knative-build
knative get pods --namespace knative-serving


# Get The Public DNS Name of the Ingress Gateway
# knative get svc istio-ingressgateway -o json -n istio-system | jq -r .status.loadBalancer.ingress[0].hostname
# af375ca60465511e9911e02b74097eec-2072757389.us-east-1.elb.amazonaws.com

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
# tmk get builds

# Deploy a Function with the Knative Lambda Runtime (KLR)

# Deploy function using Go Knative lambda runtime
# https://github.com/triggermesh/tm
tmk deploy service go-lambda -f . --runtime https://raw.githubusercontent.com/triggermesh/knative-lambda-runtime/master/go/runtime.yaml --wait
tmk deploy service go-lambda -f ./lambda/. --runtime https://raw.githubusercontent.com/triggermesh/knative-lambda-runtime/master/go/runtime.yaml --wait

# ## Install the KLR template
# tmk deploy task -f https://raw.githubusercontent.com/triggermesh/knative-lambda-runtime/master/go/runtime.yaml

# ## Verify
# tmk get buildtemplates

# tmk set registry-auth dockerhub
# Registry: index.docker.io
# Username: runseb
# Password: **********
# Registry credentials set

# tmk deploy service python-test -f https://github.com/serverless/examples \
#                               --build-template knative-python37-runtime \
#                               --build-argument DIRECTORY=aws-python-simple-http-endpoint \
#                               --build-argument HANDLER=handler.endpoint \
#                               --registry-host dockerhub \
#                               --wait