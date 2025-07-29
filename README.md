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

## Build and push the function container image

```shell
skaffold build --default-repo localhost:5001
```

## Build and deploy the function package

```shell
skaffold run --default-repo localhost:5001
```

## Clean up

Delete the function:

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
