#!/usr/bin/env bash
#
# Run a flavor locally.
#
#   ./scripts/run.sh dev
#   ./scripts/run.sh staging
#   API_BASE_URL=https://staging-api.nuvi.example ./scripts/run.sh staging
#
# Reads API_BASE_URL from the environment. Development falls back to the local
# API; staging and production have no fallback on purpose.

set -euo pipefail

FLAVOR="${1:-dev}"

case "${FLAVOR}" in
    dev|staging|prod) ;;
    *)
        echo "Usage: $0 [dev|staging|prod]" >&2
        exit 2
        ;;
esac

ENTRYPOINT="lib/main_${FLAVOR}.dart"

DEFINES=()
if [[ -n "${API_BASE_URL:-}" ]]; then
    DEFINES+=("--dart-define=API_BASE_URL=${API_BASE_URL}")
elif [[ "${FLAVOR}" != "dev" ]]; then
    echo "ERROR: API_BASE_URL must be set for the ${FLAVOR} flavor." >&2
    echo "       Shipping builds have no default; see .env.example." >&2
    exit 2
fi

if [[ -n "${API_TIMEOUT_SECONDS:-}" ]]; then
    DEFINES+=("--dart-define=API_TIMEOUT_SECONDS=${API_TIMEOUT_SECONDS}")
fi

echo "==> flutter run --flavor ${FLAVOR} -t ${ENTRYPOINT}"
exec flutter run --flavor "${FLAVOR}" -t "${ENTRYPOINT}" "${DEFINES[@]}"
