#!/usr/bin/env bash
#
# Build a release artefact for a flavor.
#
#   API_BASE_URL=https://staging-api.nuvi.example ./scripts/build.sh staging apk
#   API_BASE_URL=https://api.nuvi.example         ./scripts/build.sh prod appbundle
#
# API_BASE_URL is mandatory for staging and production: a shipped build must
# never fall back to a developer machine.

set -euo pipefail

FLAVOR="${1:-dev}"
TARGET="${2:-apk}"

case "${FLAVOR}" in
    dev|staging|prod) ;;
    *)
        echo "Usage: $0 [dev|staging|prod] [apk|appbundle|ios]" >&2
        exit 2
        ;;
esac

if [[ "${FLAVOR}" != "dev" && -z "${API_BASE_URL:-}" ]]; then
    echo "ERROR: API_BASE_URL must be set to build the ${FLAVOR} flavor." >&2
    exit 2
fi

if [[ "${FLAVOR}" == "prod" && "${API_BASE_URL:-}" != https://* ]]; then
    echo "ERROR: a production build requires an https:// API_BASE_URL." >&2
    exit 2
fi

DEFINES=()
[[ -n "${API_BASE_URL:-}" ]] && DEFINES+=("--dart-define=API_BASE_URL=${API_BASE_URL}")
[[ -n "${API_TIMEOUT_SECONDS:-}" ]] && DEFINES+=("--dart-define=API_TIMEOUT_SECONDS=${API_TIMEOUT_SECONDS}")

echo "==> flutter build ${TARGET} --flavor ${FLAVOR} -t lib/main_${FLAVOR}.dart"
exec flutter build "${TARGET}" \
    --flavor "${FLAVOR}" \
    -t "lib/main_${FLAVOR}.dart" \
    "${DEFINES[@]}"
