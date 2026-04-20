#!/usr/bin/env bash
# delete-test-mirror-entries.sh — remove {PR_NUMBER}_merge-* test image entries
# from mirror.yaml and mirror.lock.yaml in the DataDog/images repo.
#
# This script is called in the delete-test-mirror-pr GitHub workflow.
# It must be run from the root of DataDog/images.
#
# Required env var:
#   PR_NUMBER  — pull request number in dd-trace-java-docker-build (numeric)

set -euo pipefail

readonly SOURCE_PREFIX="ghcr.io/datadog/dd-trace-java-docker-build"
readonly DEST_REPO="dd-trace-java-docker-build"
readonly CI_VARIANTS=(base 7 8 11 17 21 25 tip zulu8 zulu11 oracle8 ibm8 semeru8 semeru11 semeru17 graalvm17 graalvm21 graalvm25)

if ! [[ "${PR_NUMBER}" =~ ^[0-9]+$ ]]; then
  echo "::error::PR_NUMBER must be numeric (got: '${PR_NUMBER}')" >&2
  exit 1
fi

readonly PREFIX="${PR_NUMBER}_merge-"

require_entry_exists() {
  local tag="$1"
  if ! grep -qF "\"${tag}\"" mirror.yaml; then
    echo "::error::Missing mirror.yaml tag for ${SOURCE_PREFIX}:${tag}" >&2
    exit 1
  fi
  if ! grep -qF "${SOURCE_PREFIX}:${tag}" mirror.lock.yaml; then
    echo "::error::Missing mirror.lock.yaml entry for ${SOURCE_PREFIX}:${tag}" >&2
    exit 1
  fi
}

remove_group_from_mirror_yaml() {
  local file="mirror.yaml"
  local block

  block="$(
    printf '  - source_prefix: "%s"\n    dest_repo: "%s"\n    tags:\n' "${SOURCE_PREFIX}" "${DEST_REPO}"
    for variant in "${CI_VARIANTS[@]}"; do
      printf '      - "%s%s"\n' "${PREFIX}" "${variant}"
    done
    printf '    replication_target: ""\n'
  )"

  TARGET_BLOCK="${block}" perl -0pe '
    BEGIN { $removed = 0 }
    $removed = s/\Q$ENV{TARGET_BLOCK}\E//s;
    END { exit($removed ? 0 : 44) }
  ' "${file}" > "${file}.tmp" && mv "${file}.tmp" "${file}"
}

remove_from_mirror_lock() {
  local tag="$1"
  local src="    - source: ${SOURCE_PREFIX}:${tag}"
  local file="mirror.lock.yaml"
  awk -v src="${src}" '
    $0 == src { skip_digest=1; removed=1; next }
    skip_digest && /^      digest: / { skip_digest=0; next }
    { print }
    END {
      if (!removed) {
        exit 45
      }
    }
  ' "${file}" > "${file}.tmp" && mv "${file}.tmp" "${file}"
}

echo "Validating test mirror entries for prefix '${PREFIX}'..."
for variant in "${CI_VARIANTS[@]}"; do
  require_entry_exists "${PREFIX}${variant}"
done

echo "Removing test mirror entries for prefix '${PREFIX}'..."
remove_group_from_mirror_yaml
for variant in "${CI_VARIANTS[@]}"; do
  tag="${PREFIX}${variant}"
  remove_from_mirror_lock "${tag}"
done

echo "Removed grouped mirror.yaml entry and ${#CI_VARIANTS[@]} entries from mirror.lock.yaml"
