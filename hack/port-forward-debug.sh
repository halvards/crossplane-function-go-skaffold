#!/usr/bin/env bash
#
# Sets up port-forwarding to the function Pod.
#

set -Eeufo pipefail

LOCAL_PORT=${LOCAL_PORT:-56268}
REMOTE_PORT=${REMOTE_PORT:-40000}
FUNCTION_NAME=${FUNCTION_NAME:-$(yq '.metadata.name' < ./k8s/function.yaml)}
FUNCTION_NAMESPACE=${FUNCTION_NAMESPACE:-crossplane-system}

kube_context=${SKAFFOLD_KUBE_CONTEXT:-$(kubectl config current-context)}
pod=$(kubectl --context "$kube_context" get pod --namespace "$FUNCTION_NAMESPACE" --selector pkg.crossplane.io/function="$FUNCTION_NAME" --output name | head -n1)

echo "Starting port-forwarding to port $REMOTE_PORT on function $pod, connect your debugger to local port $LOCAL_PORT..."
# Closing stdout and stderr so Skaffold thinks the process has finished, and proceeds to watch for changes.
# See https://stackoverflow.com/a/26420299
kubectl --context "$kube_context" port-forward "$pod" "$LOCAL_PORT":"$REMOTE_PORT" >&- 2>&- &
