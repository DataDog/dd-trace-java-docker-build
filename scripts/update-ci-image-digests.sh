#!/usr/bin/env bash
# update-ci-image-digests.sh - add/update ci-* image mirror entries in the DataDog/images repo.
#
# This script is called in the update-mirror-digests Github workflow.
# It must be run from the root of DataDog/images and requires crane to be installed.

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SOURCE_PREFIX="ghcr.io/datadog/dd-trace-java-docker-build"
readonly DEST_REPO="dd-trace-java-docker-build"

is_amd64_only_variant() {
  [[ "$1" == "7" || "$1" == "ibm8" ]]
}

append_mirror_yaml_entry() {
  local variant="$1" tag="ci-${variant}"

  {
    printf '  - source: "%s:%s"\n' "${SOURCE_PREFIX}" "${tag}"
    printf '    dest:\n'
    printf '      repo: "%s"\n' "${DEST_REPO}"
    printf '      tag: "%s"\n' "${tag}"
    printf '    replication_target: ""\n'
    printf '    platforms:\n'
    printf '      - "linux/amd64"\n'
    if ! is_amd64_only_variant "${variant}"; then
      printf '      - "linux/arm64"\n'
    fi
    printf '    renovate:\n'
    printf '      enabled: true\n'
  } >> mirror.yaml
}

append_mirror_lock_entry() {
  local tag="$1" digest="$2"

  printf '    # renovate\n    - source: %s:%s\n      digest: %s\n' \
    "${SOURCE_PREFIX}" "${tag}" "${digest}" >> mirror.lock.yaml
}

readonly PREFIX="ci-"
# shellcheck source=scripts/get-image-digests.sh
source "${SCRIPT_DIR}/get-image-digests.sh"

for variant in "${CI_VARIANTS[@]}"; do
  tag="ci-${variant}"
  source="${SOURCE_PREFIX}:${tag}"

  if ! grep -qF "${source}" mirror.yaml; then
    append_mirror_yaml_entry "${variant}"
    echo "Added mirror.yaml entry: ${tag}"
  fi

  if ! grep -qF "${source}" mirror.lock.yaml; then
    append_mirror_lock_entry "${tag}" "${DIGESTS[$variant]}"
    echo "Added mirror.lock.yaml entry: ${tag}"
  fi

  update_digest "${tag}" "${DIGESTS[$variant]}" mirror.lock.yaml
  echo "Updated mirror.lock.yaml: ${tag}"
done
