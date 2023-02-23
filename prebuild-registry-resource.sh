#!/usr/bin/env bash

set -eu -o pipefail

own_dir="$(readlink -f "$(dirname "${BASH_SOURCE[0]}")")"
dockerfile="${own_dir}/concourse-resource-registry-image.dockerfile"

if [ ! -z "${BUILD_DIR:-}" ]; then
  build_dir="${BUILD_DIR}"
else
  build_dir="${own_dir}"
fi

outdir="${build_dir}/resource-types"

mkdir -p "${outdir}/registry-image"

echo '{
  "type": "registry-image",
  "version": "1.7.0",
  "privileged": false,
  "unique_version_history": false
}' > "${outdir}/registry-image/resource_metadata.json"

echo "running docker-build"

docker \
  buildx \
  build \
  --tag concourse-resource-registry-image:tmp \
  -f "${dockerfile}" \
  "${build_dir}"

echo "exporting image-fs"

img="$(docker create --name registry-image concourse-resource-registry-image:tmp dummy)"
echo "writing image to ${outdir}/registry-image/root.tgz"
docker export "${img}" | gzip > "${outdir}/registry-image/rootfs.tgz"

