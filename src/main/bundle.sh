
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
WORKSPACE_DIR="${REPO_ROOT}/src"
TARGET_DIR="${WORKSPACE_DIR}/target"

OUTDIR="${1:-bundle_out}"
mkdir -p "$OUTDIR"

# Map: rust target triple -> desired output filename
declare -A MAP=(
  ["x86_64-unknown-linux-gnu"]="librust-linux-x86_64.so"
  ["aarch64-unknown-linux-gnu"]="librust-linux-aarch64.so"
  ["x86_64-pc-windows-gnu"]="librust-windows-x86_64.dll"
)

# Find produced library file for a target (supports common naming)
find_lib() {
  local triple="$1"
  local dir="${TARGET_DIR}/${triple}/release"
  # try known patterns
  if compgen -G "${dir}/librust.so" > /dev/null; then echo "${dir}/librust.so"; return; fi
  if compgen -G "${dir}/librust.dll" > /dev/null; then echo "${dir}/librust.dll"; return; fi
  # fallback: any .so/.dll starting with lib and reasonable size
  local f
  f="$(ls -1 "${dir}"/*.so 2>/dev/null | head -n 1 || true)"
  if [[ -n "${f}" ]]; then echo "${f}"; return; fi
  f="$(ls -1 "${dir}"/*.dll 2>/dev/null | head -n 1 || true)"
  if [[ -n "${f}" ]]; then echo "${f}"; return; fi
  echo ""
}

echo "[*] Staging libs into: $OUTDIR"

for triple in "${!MAP[@]}"; do
  src="$(find_lib "$triple")"
  if [[ -z "$src" ]]; then
    echo "[!] Missing build output for target $triple (did you run build script?)"
    exit 1
  fi
  dst="${OUTDIR}/${MAP[$triple]}"
  echo "  - $triple: $src -> $dst"
  cp -f "$src" "$dst"
done

# Add required runtime params if present in repo (adjust paths as needed)
copy_if_exists() {
  local p="$1"
  if [[ -f "$p" ]]; then
    echo "  - adding $p"
    cp -f "$p" "$OUTDIR/"
  else
    echo "  - (missing) $p"
  fi
}

# These paths may differ in your repo; update if needed
copy_if_exists "${REPO_ROOT}/saplingspend_base64"
copy_if_exists "${REPO_ROOT}/saplingoutput_base64"
copy_if_exists "${REPO_ROOT}/coinparams.json"

# version file (write something useful if it doesn't exist)
if [[ -f "${REPO_ROOT}/version" ]]; then
  cp -f "${REPO_ROOT}/version" "$OUTDIR/version"
fi

echo "[*] Bundle contents:"
ls -lh "$OUTDIR"
