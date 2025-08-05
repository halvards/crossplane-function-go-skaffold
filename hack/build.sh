#!/usr/bin/env bash
#
# Builds and pushes the Crossplane function package container image.

set -Exefo pipefail

# shellcheck disable=SC2034
GO_PACKAGE=${1:-.}

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

# TODO: Implement multi-platform builds - requires separate function package files for each platform.
platform=$(cut -d, -f1 <<< "$PLATFORMS")
if [[ "$PLATFORMS" != "$platform" ]]; then
  echo "error: multi-platform builds has not been implemented yet in this build script" >&2
  exit 1
fi
mkdir -p "bin/$platform"

# Build the container image using Docker.
echo "Building container image for $platform with base image $RUNTIME_IMAGE"
docker build . \
  --build-arg CGO_ENABLED \
  --build-arg GOFLAGS \
  --build-arg GO_GCFLAGS \
  --build-arg GO_PACKAGE \
  --build-arg RUNTIME_IMAGE \
  --file ./Dockerfile \
  --platform "$platform" \
  --quiet \
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

# PUSH_IMAGE and IMAGE are environment variables provided by Skaffold to this script:
# https://skaffold.dev/docs/builders/builder-types/custom/
if [[ "${PUSH_IMAGE}" == "true" ]]; then
  echo "Pushing $IMAGE"
  crossplane xpkg push --package-files="$function_package_file" "$IMAGE" --insecure
else
  echo "Loading $IMAGE to local Docker daemon"
  docker_load_output=$(docker load --input "$function_package_file" --quiet)
  docker_image_id=$(echo "$docker_load_output" | awk '{print $4}')
  docker tag "$docker_image_id" "$IMAGE"
fi
