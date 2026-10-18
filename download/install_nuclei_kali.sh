#!/usr/bin/env bash
# Install/update ProjectDiscovery Nuclei and its official community templates on Kali/Linux.
# Installs the binary and templates under the current user's home directory; no sudo required.
set -Eeuo pipefail

REPO="projectdiscovery/nuclei"
BIN_DIR="${HOME}/.local/bin"
TEMPLATE_DIR="${HOME}/.local/nuclei-templates"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

log()  { printf '\n[+] %s\n' "$*"; }
warn() { printf '\n[!] %s\n' "$*" >&2; }
die()  { printf '\n[ERROR] %s\n' "$*" >&2; exit 1; }

for cmd in curl unzip awk grep find; do
  command -v "$cmd" >/dev/null 2>&1 || die "Required command '$cmd' is missing. Install it with: sudo apt update && sudo apt install -y curl unzip"
done

case "$(uname -m)" in
  x86_64|amd64)  ASSET="nuclei-linux-amd64.zip" ;;
  aarch64|arm64) ASSET="nuclei-linux-arm64.zip" ;;
  *)
    die "Unsupported CPU architecture: $(uname -m). Install Nuclei manually from https://github.com/${REPO}/releases"
    ;;
esac

mkdir -p "$BIN_DIR" "$TEMPLATE_DIR"

log "Downloading the latest official Nuclei release ($ASSET)..."
DOWNLOAD_URL="https://github.com/${REPO}/releases/latest/download/${ASSET}"
curl --fail --location --silent --show-error --retry 3 "$DOWNLOAD_URL" -o "$WORK_DIR/nuclei.zip" \
  || die "Could not download Nuclei. Check internet access, DNS, and GitHub availability."

unzip -oq "$WORK_DIR/nuclei.zip" -d "$WORK_DIR/unpacked" \
  || die "The downloaded release archive could not be extracted."

NEW_BINARY="$(find "$WORK_DIR/unpacked" -type f -name nuclei -perm /111 -print -quit)"
[[ -n "$NEW_BINARY" ]] || die "No executable named 'nuclei' was found in the release archive."

install -m 0755 "$NEW_BINARY" "${BIN_DIR}/nuclei"
export PATH="${BIN_DIR}:${PATH}"

# Persist the user-local binary path for common interactive shells, without duplicate lines.
PATH_LINE='export PATH="$HOME/.local/bin:$PATH"'
for rc in "${HOME}/.bashrc" "${HOME}/.zshrc"; do
  if [[ -f "$rc" ]] && ! grep -Fqx "$PATH_LINE" "$rc"; then
    printf '\n# User-local tools\n%s\n' "$PATH_LINE" >> "$rc"
  fi
done

log "Installed Nuclei binary:"
nuclei -version

log "Downloading/updating official nuclei-templates to: $TEMPLATE_DIR"
nuclei -update-templates -update-template-dir "$TEMPLATE_DIR" \
  || die "Nuclei could not update templates. Check the error above; common causes are network access or GitHub being blocked."

log "Verifying template files..."
YAML_COUNT="$(find "$TEMPLATE_DIR" -type f \( -name '*.yaml' -o -name '*.yml' \) | wc -l | awk '{print $1}')"
[[ "$YAML_COUNT" =~ ^[0-9]+$ ]] || die "Could not count template files."
(( YAML_COUNT > 0 )) || die "Template update returned, but no YAML template files were found in $TEMPLATE_DIR."

log "Verifying Nuclei can load templates..."
TEMPLATE_LIST="$WORK_DIR/template-list.txt"
nuclei -tl -ud "$TEMPLATE_DIR" >"$TEMPLATE_LIST" 2>&1 \
  || die "Nuclei failed while listing templates. Diagnostic output follows: $(cat "$TEMPLATE_LIST")"

if ! grep -qE 'Listing available|templates for|\.ya?ml' "$TEMPLATE_LIST"; then
  warn "Nuclei returned output, but the template listing did not match the expected format."
  cat "$TEMPLATE_LIST"
fi

printf '\n========== VERIFICATION SUMMARY ==========\n'
printf 'Nuclei binary:       %s\n' "$(command -v nuclei)"
printf 'Template directory:  %s\n' "$TEMPLATE_DIR"
printf 'YAML template files: %s\n' "$YAML_COUNT"
printf '\nNuclei version:\n'
nuclei -version
printf '\nTemplate version:\n'
nuclei -tv -ud "$TEMPLATE_DIR"
printf '\nSample installed templates:\n'
find "$TEMPLATE_DIR" -type f \( -name '*.yaml' -o -name '*.yml' \) -print | head -n 10

printf '\n[SUCCESS] Nuclei and its templates are installed and basic checks passed.\n'
printf 'Run: nuclei -h\n'
printf 'For future template updates: nuclei -update-templates -update-template-dir "%s"\n' "$TEMPLATE_DIR"
printf 'Only scan systems you own or are explicitly authorized to test.\n'
