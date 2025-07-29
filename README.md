# crossplane-function-go-skaffold

Build and deploy a Crossplane composition function written in Go, using
[Skaffold](https://skaffold.dev).

## Tools required

```shell
brew bundle install
```

## Kubernetes cluster and container image registry

Start a local Kubernetes cluster using [`kind`](https://kind.sigs.k8s.io/),
and a
[local container image registry](https://kind.sigs.k8s.io/docs/user/local-registry/#create-a-cluster-and-registry):

```shell
curl -sL https://raw.githubusercontent.com/kubernetes-sigs/kind/ba3f8b4cb58e0ac038248233d158c91e875fb85b/site/static/examples/kind-with-registry.sh | bash
```

## Install Crossplane

```shell
helm repo add crossplane-stable https://charts.crossplane.io/stable
helm repo update
helm install crossplane crossplane-stable/crossplane \
  --namespace crossplane-system \
  --create-namespace \
  --version 1.20.0

kubectl rollout status --namespace crossplane-system deployment/crossplane --timeout 180s
kubectl rollout status --namespace crossplane-system deployment/crossplane-rbac-manager --timeout 180s
```

## Install Crossplane providers and functions

```shell
crossplane xpkg install provider xpkg.upbound.io/crossplane-contrib/provider-nop:v0.4.0
crossplane xpkg install function xpkg.upbound.io/crossplane-contrib/function-auto-ready:v0.5.0

kubectl wait --for condition=healthy provider.pkg.crossplane.io/crossplane-contrib-provider-nop --timeout 60s
kubectl wait --for condition=healthy function.pkg.crossplane.io/crossplane-contrib-function-auto-ready --timeout 60s
```

## Build and push the function container image that is defined in this repository

```shell
skaffold build --default-repo localhost:5001
```

## Build and deploy the function package

```shell
skaffold run --default-repo localhost:5001
```

## Remote debugging

```shell
skaffold debug --default-repo localhost:5001
```

Connect your debugger to localhost port 56268 and set your breakpoints!

## Clean up

Delete the function and all of its owned resources:

```shell
skaffold delete
```

Delete the `kind` cluster:

```shell
kind delete cluster
```

## Tips

- Add the `--cache-artifacts=false` flag to the Skaffold commands to force a
  rebuild of the container image.

## Disclaimer

This is not an officially supported Atlassian product.
