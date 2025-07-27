#!/usr/bin/env bash
set -Eefo pipefail
go_package=${1:-.}
export KO_DEFAULTBASEIMAGE=${RUNTIME_IMAGE:-gcr.io/distroless/static-debian12:nonroot}

if ! command -v ko >/dev/null 2>&1; then
  go install github.com/google/ko@latest
fi

# TODO: Implement multi-platform builds - requires separate tarballs for each platform.
echo "Building for platforms: $PLATFORMS"
platform=$(cut -d, -f1 <<< "$PLATFORMS")
mkdir -p "bin/$platform"

# Build the container image using ko and create a tarball.
image_tarball="./bin/$platform/image.tar.gz"
rm -f "$image_tarball"
echo "Building container image tarball to $image_tarball"
ko build \
  --platform="$platform" \
  --push=false \
  --tags= \
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

if [[ "${PUSH_IMAGE}" == "true" ]]; then
  echo "Pushing $IMAGE"
  crane push "$function_package_file" "$IMAGE"
else
  echo "Loading $IMAGE to local Docker daemon"
  docker_load_output=$(docker load --input "$function_package_file" --quiet)
  docker_image_id=$(echo "$docker_load_output" | awk '{print $4}')
  docker tag "$docker_image_id" "$IMAGE"
fi
