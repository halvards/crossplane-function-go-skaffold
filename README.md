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

## Create the composite resource definition (XRD)

```shell
kubectl apply --filename examples/definition.yaml
kubectl wait xrd xnetworks.example.atlassian.com --for condition=Established --timeout 30s
```

## Create the composition

```shell
kubectl apply --filename examples/composition.yaml
```

## Build and deploy the function package

Three different modes are available, `run`, `dev`, and `debug`:

1.  Build and deploy:

    ```shell
    skaffold run --default-repo localhost:5001
    ```
    
    To delete the function:

    ```shell
    skaffold delete
    ```

2.  Build and deploy, then set file watches.
    Rebuild and redeploy on any source code changes: 

    ```shell
    skaffold dev --default-repo localhost:5001
    ```

3.  Build with a bundled Go debugger (Delve), and deploy with port-forwarding
    to the debugging port on the Pod:

    ```shell
    skaffold debug --default-repo localhost:5001
    ```

    Connect your debugger to `localhost` port `56268` and set breakpoints.

## Tips

- Add the `--cache-artifacts=false` flag to Skaffold commands to bypass
  Skaffold's cache and force a rebuild of the container image.

- You can just build the function package and push it to your container
  image registry, without deploying it to a cluster:

  ```shell
  skaffold build --default-repo localhost:5001
  ```

## Clean up

Delete the `kind` cluster:

```shell
kind delete cluster
```

## Disclaimer

This is not an officially supported Atlassian product.
