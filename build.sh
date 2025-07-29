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

if ! command -v ko >/dev/null 2>&1; then
  go install github.com/google/ko@latest
fi

# TODO: Implement multi-platform builds - requires separate tarballs for each platform.
echo "Building for platforms: $PLATFORMS"
platform=$(cut -d, -f1 <<< "$PLATFORMS")
mkdir -p "bin/$platform"

# Build and push the container image using ko.
image_base_name=$(rev <<< "$IMAGE" | cut -d: -f2- | rev)
tag=$(rev <<< "$IMAGE" | cut -d: -f1 | rev)

echo "Building container image for $platform"
ko_output=$(KO_DOCKER_REPO=$image_base_name ko build \
  --bare \
  --debug="$debug" \
  --platform="$platform" \
  --push=true \
  --sbom none \
  --tags "${tag}-base" \
  "$go_package" | tee)
# Capture the image reference from the last line of the output of `ko build`.
image_ref=$(echo "$ko_output" | tail -n1)

if [[ $debug == "true" ]]; then
  echo "Adding delve debugging support and enabling debug logging"
  # shellcheck disable=SC2046
  crane_output=$(crane mutate "$image_ref" --entrypoint $(crane config "$image_ref" | jq --raw-output '[ .config.Entrypoint[0:2][], "--continue", .config.Entrypoint[2:][], "--debug" ] | @csv'))
  # Capture the image reference from the last line of the output of `crane mutate`.
  image_ref=$(echo "$crane_output" | tail -n1)
fi

# Pull the container image to a tarball.
image_tarball="./bin/$platform/image.tar.gz"
rm -f "$image_tarball"
crane pull "$image_ref" "$image_tarball" --platform "$platform" --insecure

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
