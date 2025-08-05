# syntax=docker/dockerfile:1

# Used by the GitHub Actions workflow.

# We use the latest Go 1.x version unless asked to use something else.
# The GitHub Actions CI job sets this argument for a consistent Go version.
ARG GO_VERSION=1
ARG RUNTIME_IMAGE=gcr.io/distroless/static-debian12:nonroot

# Setup the base environment. The BUILDPLATFORM is set automatically by Docker.
# The --platform=${BUILDPLATFORM} flag tells Docker to build the function using
# the OS and architecture of the host running the build, not the OS and
# architecture that we're building the function for.
FROM --platform=${BUILDPLATFORM} golang:${GO_VERSION} AS build

WORKDIR /fn

# Most functions don't want or need CGo support, so we disable it.
# If CGo support is needed make sure to also change the base image to one that
# includes glibc, like 'distroless/base'.
ARG CGO_ENABLED=0
#ENV CGO_ENABLED=${CGO_ENABLED}

# We run go mod download in a separate step so that we can cache its results.
# This lets us avoid re-downloading modules if we don't need to. The type=target
# mount tells Docker to mount the current directory read-only in the WORKDIR.
# The type=cache mount tells Docker to cache the Go modules cache across builds.
RUN --mount=target=. --mount=type=cache,target=/go/pkg/mod go mod download

# The TARGETOS and TARGETARCH args are set by docker. We set GOOS and GOARCH to
# these values to ask Go to compile a binary for these architectures. If
# TARGETOS and TARGETOS are different from BUILDPLATFORM, Go will cross compile
# for us (e.g. compile a linux/amd64 binary on a linux/arm64 build machine).
ARG TARGETOS
ARG TARGETARCH

# Specify the Go package to build
ARG GO_PACKAGE=.

# Optimizations on by default.
# Pass GOFLAGS="-gcflags='all=-N -l'" to enable debugging by disabling compiler optimizations.
ARG GOFLAGS="-trimpath"
ARG GO_GCFLAGS=""

RUN --mount=target=. \
    --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=${CGO_ENABLED} GOOS=${TARGETOS} GOARCH=${TARGETARCH} go build ${GOFLAGS} -gcflags="${GO_GCFLAGS}" -o /function ./cmd/fn

# Produce the Function image. We use a very lightweight 'distroless' image that
# does not include any of the build tools used in previous stages.
FROM ${RUNTIME_IMAGE} AS image
WORKDIR /
COPY --from=build /function /function
EXPOSE 9443
USER nonroot:nonroot
ENTRYPOINT ["/function"]
