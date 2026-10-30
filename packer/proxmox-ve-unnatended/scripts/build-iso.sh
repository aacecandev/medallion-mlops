#!/usr/bin/env bash
# Render an answer-file template with secrets read from STDIN (dotenv
# format), validate it and, unless --validate-only is given, embed it into
# the stock Proxmox VE ISO.
#
# Usage (from packer/proxmox-ve-unnatended):
#   sops -d secrets.sops.env | scripts/build-iso.sh <host> [--validate-only]
#   scripts/build-iso.sh <host> [--validate-only] < ci/secrets.ci.env
#
# Environment: CONTAINER_ENGINE (default docker), AIA_IMAGE (required).
# The assistant always runs in the container image, locally and in CI.
set -euo pipefail

usage() {
  echo "usage: $0 <host> [--validate-only] < secrets.env" >&2
  exit 2
}

[ $# -ge 1 ] && [ $# -le 2 ] || usage
host="$1"
validate_only=false
if [ $# -eq 2 ]; then
  [ "$2" = "--validate-only" ] || usage
  validate_only=true
fi

ISO_NAME="${PVE_ISO_NAME:-proxmox-ve_9.2-1.iso}"
engine="${CONTAINER_ENGINE:-docker}"
: "${AIA_IMAGE:?AIA_IMAGE must be set (see root mise.toml)}"

cd "$(dirname "$0")/.."
tmpl="answers/${host}.toml.tmpl"
[ -f "${tmpl}" ] || { echo "no template for host '${host}': ${tmpl}" >&2; exit 2; }

# Read KEY=VALUE lines. No eval/source: values (e.g. crypt hashes with '$')
# are never expanded by the shell.
ROOT_PASSWORD_HASHED=""
MAILTO=""
while IFS='=' read -r key value || [ -n "${key}" ]; do
  case "${key}" in
    ROOT_PASSWORD_HASHED) ROOT_PASSWORD_HASHED="${value}" ;;
    MAILTO) MAILTO="${value}" ;;
  esac
done
for var in ROOT_PASSWORD_HASHED MAILTO; do
  value="${!var}"
  if [ -z "${value}" ] || [ "${value}" = "CHANGEME" ]; then
    echo "${var} is empty or CHANGEME: set it with 'sops secrets.sops.env'" >&2
    exit 1
  fi
done
export ROOT_PASSWORD_HASHED MAILTO

umask 077
mkdir -p build
answer="build/${host}.toml"
envsubst '${ROOT_PASSWORD_HASHED} ${MAILTO}' < "${tmpl}" > "${answer}"

aia() {
  "${engine}" run --rm --user "$(id -u):$(id -g)" -v "${PWD}:/work" "${AIA_IMAGE}" "$@"
}

aia validate-answer "${answer}"
echo "answer file valid: ${answer}"

if [ "${validate_only}" = true ]; then
  exit 0
fi

[ -f "${ISO_NAME}" ] || { echo "stock ISO not found: ${ISO_NAME}" >&2; exit 1; }
out="build/${ISO_NAME%.iso}-${host}.iso"
aia prepare-iso "${ISO_NAME}" --fetch-from iso --answer-file "${answer}" --output "${out}"
echo "prepared ISO (contains secrets in plaintext, do not share): ${out}"
