#!/usr/bin/env bash
#
# Builds and pushes the Crossplane function package container image.

set -Eefo pipefail

# shellcheck disable=SC2034
GO_PACKAGE=${1:-.}

# shellcheck disable=SC2034
BUILDER_IMAGE=docker.io/library/golang:1
RUNTIME_IMAGE=gcr.io/distroless/static-debian12:nonroot
CGO_ENABLED=${CGO_ENABLED:-0}
if [[ $CGO_ENABLED == "1" ]]; then
  echo "CGO is enabled, using base image with glibc"
  RUNTIME_IMAGE=gcr.io/distroless/base-debian12:nonroot
fi
debug=${DEBUG:-false}
GOFLAGS="${GOFLAGS:-"-trimpath"}"
GO_GCFLAGS="${GO_GCFLAGS:-}"
if [[ $debug == "true" ]]; then
  echo "Debug mode is enabled"
  RUNTIME_IMAGE=gcr.io/distroless/base-debian12:debug
  GOFLAGS=""
  GO_GCFLAGS="all=-N -l"
fi

function_package_files=()
for platform in ${PLATFORMS//,/ }; do

  mkdir -p "bin/$platform"

  # Build the container image using Docker.
  echo "Building container image for $platform with base image $RUNTIME_IMAGE"
  docker build . \
    --build-arg BUILDER_IMAGE \
    --build-arg CGO_ENABLED \
    --build-arg GOFLAGS \
    --build-arg GO_GCFLAGS \
    --build-arg GO_PACKAGE \
    --build-arg RUNTIME_IMAGE \
    --file ./Dockerfile \
    --platform "$platform" \
    --tag "$IMAGE-base"

  # Build the crossplane package from the container image tarball.
  function_package_file="./bin/$platform/function-package.xpkg"
  rm -f "$function_package_file"
  echo "Building Crossplane function package to $function_package_file"
  crossplane xpkg build \
    --embed-runtime-image="$IMAGE-base" \
    --examples-root=examples \
    --package-file="$function_package_file" \
    --package-root=package

  function_package_files+=("$function_package_file")

done

# PUSH_IMAGE and IMAGE are environment variables provided by Skaffold to this script:
# https://skaffold.dev/docs/builders/builder-types/custom/
package_files=$(echo "${function_package_files[@]}" | tr ' ' ',')
if [[ "${PUSH_IMAGE}" == "true" ]]; then
  echo "Pushing $IMAGE"
  crossplane xpkg push --package-files="$package_files" "$IMAGE" --insecure-skip-tls-verify
else
  for function_package_file in "${function_package_files[@]}"; do
    echo "Loading $IMAGE for $platform to local Docker daemon"
    docker_load_output=$(docker load --input "$function_package_file" --quiet)
    docker_image_id=$(echo "$docker_load_output" | awk '{print $4}')
    docker tag "$docker_image_id" "$IMAGE"
  done
fi
