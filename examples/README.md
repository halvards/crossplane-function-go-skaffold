# Example manifests

You can run your function locally and test it using `crossplane render`
with these example manifests.

```shell
# Run the function locally
$ go run . --insecure --debug
```

```shell
# Then, in another terminal, call the function with these example manifests
$ crossplane render xr.yaml composition.yaml function.yaml
```
