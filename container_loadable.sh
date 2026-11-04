#!/usr/bin/env bash
# Convert a built OCI archive into an archive that every Docker image store
# can load.
#
# usage: ./container_loadable.sh <container-amd64|container-arm64|container-armv7>
set -euo pipefail

cd "$(dirname "$0")"

usage() {
    echo "Usage: $0 <container-amd64|container-arm64|container-armv7>" >&2
    exit 1
}

[ "$#" -eq 1 ] || usage
MACHINE="$1"

case "$MACHINE" in
    container-amd64|container-arm64|container-armv7) ;;
    *) echo "ERROR: unknown machine '$MACHINE'" >&2; usage ;;
esac

if ! command -v skopeo >/dev/null 2>&1; then
    echo "ERROR: skopeo not found on PATH" >&2
    exit 1
fi

DEPLOY_IMAGES="deploy/venus/images/${MACHINE}"
shopt -s nullglob
archives=("${DEPLOY_IMAGES}"/venus-container-*-oci.tar)
shopt -u nullglob
if [ "${#archives[@]}" -ne 1 ]; then
    echo "ERROR: expected one OCI archive reference in $DEPLOY_IMAGES" >&2
    exit 1
fi

link="${archives[0]##*/}"
version="${link#venus-container-}"
version="${version%-oci.tar}"

# the link points to venus-container-<machine>-<datetime>-<version>-oci-<version>-...
archive="$(readlink "${archives[0]}")"
build="${archive%-oci-"${version}"-*}"
if [ "$build" = "$archive" ]; then
    echo "ERROR: cannot derive the build from $archive" >&2
    exit 1
fi

LOADABLE="${DEPLOY_IMAGES}/${build}-loadable.tar"
LOADABLE_LINK="${DEPLOY_IMAGES}/venus-container-${MACHINE}-loadable.tar"

# bitbake removes the previous build's images, so remove its archive too
rm -f "${DEPLOY_IMAGES}/venus-container-${MACHINE}"-*-loadable.tar
skopeo copy --quiet \
    "oci-archive:${DEPLOY_IMAGES}/${archive}" \
    "docker-archive:${LOADABLE}:container-gx:${version}"
ln -sfn "${LOADABLE##*/}" "$LOADABLE_LINK"

echo "Created $LOADABLE"
