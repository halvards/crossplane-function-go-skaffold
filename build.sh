#!/usr/bin/env bash
set -Eefo pipefail

go_package=${1:-.}
debug=${DEBUG:-false}
default_base_image=gcr.io/distroless/static-debian12:nonroot
if [[ $CGO_ENABLED == "1" ]]; then
  echo "CGO is enabled, using base image with glibc"
  default_base_image=gcr.io/distroless/base-debian12:nonroot
fi
if [[ $debug == "true" ]]; then
  echo "Debug mode is enabled"
  default_base_image=gcr.io/distroless/base-debian12:debug
fi
export KO_DEFAULTBASEIMAGE=${RUNTIME_IMAGE:-$default_base_image}

# TODO: Implement multi-platform builds - requires separate tarballs for each platform.
platform=$(cut -d, -f1 <<< "$PLATFORMS")
if [[ "$PLATFORMS" != "$platform" ]]; then
  echo "error: multi-platform builds has not been implemented yet in this build script" >&2
  exit 1
fi
mkdir -p "bin/$platform"

# Build the container image as a tarball using ko.
image_tarball="./bin/$platform/image.tar.gz"
rm -f "$image_tarball"
echo "Building container image to tarball $image_tarball"
ko build \
  --debug="$debug" \
  --disable-optimizations="$debug" \
  --platform="$platform" \
  --push=false \
  --tarball="$image_tarball" \
  "$go_package"

# Build the crossplane package from the container image tarball.
function_package_file="./bin/$platform/function-package.xpkg"
rm -f "$function_package_file"
echo "Building Crossplane function package to $function_package_file"
crossplane xpkg build \
  --embed-runtime-image-tarball="$image_tarball" \
  --examples-root=examples \
  --package-file="$function_package_file" \
  --package-root=package

# PUSH_IMAGE and IMAGE are environment variables provided by Skaffold to this script:
# https://skaffold.dev/docs/builders/builder-types/custom/
if [[ "${PUSH_IMAGE}" == "true" ]]; then
  echo "Pushing $IMAGE"
  crane push "$function_package_file" "$IMAGE" --insecure
else
  echo "Loading $IMAGE to local Docker daemon"
  docker_load_output=$(docker load --input "$function_package_file" --quiet)
  docker_image_id=$(echo "$docker_load_output" | awk '{print $4}')
  docker tag "$docker_image_id" "$IMAGE"
fi
