#!/usr/bin/env bash
# update-ci-image-digests.sh - add/update ci-* image mirror entries in the DataDog/images repo.
#
# This script is called in the update-mirror-digests Github workflow.
# It must be run from the root of DataDog/images and requires crane to be installed.

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SOURCE_PREFIX="ghcr.io/datadog/dd-trace-java-docker-build"
readonly DEST_REPO="dd-trace-java-docker-build"

insert_mirror_yaml_entry() {
  local variant="$1" tag="ci-${variant}" amd64_only="false"

  if [[ "${variant}" == "7" || "${variant}" == "ibm8" ]]; then
    amd64_only="true"
  fi

  awk -v source_prefix="${SOURCE_PREFIX}" -v dest_repo="${DEST_REPO}" -v tag="${tag}" -v amd64_only="${amd64_only}" '
    /^image_groups:$/ && !inserted {
      print "  - source: \"" source_prefix ":" tag "\""
      print "    dest:"
      print "      repo: \"" dest_repo "\""
      print "      tag: \"" tag "\""
      print "    replication_target: \"\""
      print "    platforms:"
      print "      - \"linux/amd64\""
      if (amd64_only != "true") {
        print "      - \"linux/arm64\""
      }
      print "    renovate:"
      print "      enabled: true"
      inserted = 1
    }
    { print }
    END {
      if (!inserted) {
        print "missing top-level image_groups section in mirror.yaml" > "/dev/stderr"
        exit 1
      }
    }
  ' mirror.yaml > mirror.yaml.tmp && mv mirror.yaml.tmp mirror.yaml
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
    insert_mirror_yaml_entry "${variant}"
    echo "Added mirror.yaml entry: ${tag}"
  fi

  if ! grep -qF "${source}" mirror.lock.yaml; then
    append_mirror_lock_entry "${tag}" "${DIGESTS[$variant]}"
    echo "Added mirror.lock.yaml entry: ${tag}"
  fi
done

for variant in "${CI_VARIANTS[@]}"; do
  tag="ci-${variant}"
  update_digest "${tag}" "${DIGESTS[$variant]}" mirror.lock.yaml
  echo "Updated mirror.lock.yaml: ${tag}"
done
