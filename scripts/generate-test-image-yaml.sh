#!/usr/bin/env bash
# In order to test the images built by your PR in dd-trace-java CI, the images must first be mirrored into the DataDog/images repo.
# Use this script to generate the YAML snippets that need to be added to mirror.yaml and mirror.lock.yaml in DataDog/images.
# Before running, ensure that the expected images are available here: https://github.com/DataDog/dd-trace-java-docker-build/pkgs/container/dd-trace-java-docker-build.
#
# Usage:
#   ./scripts/generate-test-image-yaml.sh <PR_NUM>
#
# Example:
#   ./scripts/generate-test-image-yaml.sh 138
#
# Requires:
#   crane (install with `brew install crane`)
set -euo pipefail

readonly SOURCE_REPO="ghcr.io/datadog/dd-trace-java-docker-build"

readonly CI_VARIANTS=(
    base
    7
    8
    11
    17
    21
    25
    tip
    zulu8
    zulu11
    oracle8
    ibm8
    semeru8
    semeru11
    semeru17
    graalvm17
    graalvm21
    graalvm25
)

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <PR_NUM>" >&2
    echo "Example: $0 138" >&2
    exit 1
fi

PR_NUM="$1"
if ! [[ "$PR_NUM" =~ ^[0-9]+$ ]]; then
    echo "Error: PR_NUM must be a number (got: '$PR_NUM')" >&2
    exit 1
fi

if ! command -v crane &>/dev/null; then
    echo "Error: 'crane' is required but not found. Install with 'brew install crane'." >&2
    exit 1
fi

readonly PREFIX="${PR_NUM}_merge-"

echo "Resolving digests for ${#CI_VARIANTS[@]} variants (prefix: '${PREFIX}')..." >&2

declare -A DIGESTS
for variant in "${CI_VARIANTS[@]}"; do
    tag="${PREFIX}${variant}"
    echo -n "  ${tag} ... " >&2
    digest="$(crane digest "${SOURCE_REPO}:${tag}")"
    DIGESTS["$variant"]="$digest"
    echo "$digest" >&2
done

echo "" >&2

cat <<EOF
### Add to https://github.com/DataDog/images/blob/master/mirror.yaml:

EOF

for variant in "${CI_VARIANTS[@]}"; do
    tag="${PREFIX}${variant}"
    cat <<EOF
  - source: "${SOURCE_REPO}:${tag}"
    dest:
      repo: "dd-trace-java-docker-build"
      tag: "${tag}"
    replication_target: ""
    renovate:
      enabled: true
EOF
done

cat <<EOF

### Add to https://github.com/DataDog/images/blob/master/mirror.lock.yaml:

EOF

for variant in "${CI_VARIANTS[@]}"; do
    tag="${PREFIX}${variant}"
    cat <<EOF
    # renovate
    - source: ${SOURCE_REPO}:${tag}
      digest: ${DIGESTS[$variant]}
EOF
done

cat <<EOF

### Set in https://github.com/DataDog/dd-trace-java/blob/master/.gitlab-ci.yml:

TESTER_IMAGE_VERSION_PREFIX: "${PREFIX}"
EOF
