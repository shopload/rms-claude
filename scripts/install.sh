#!/usr/bin/env sh
# Installs the latest rms-cli release for macOS or Linux.
#
# Requires: gh (GitHub CLI) — https://cli.github.com
# The gh CLI handles authentication for private repositories automatically.
#
# Usage:
#   sh scripts/install.sh
#
# Env vars (optional):
#   RMS_CLI_INSTALL_DIR  where to install (default: /usr/local/bin, falling
#                        back to $HOME/.local/bin if that's not writable)
#   RMS_CLI_VERSION      specific version tag to install (default: latest)

set -eu

repo="shopload/rms-claude"

if ! command -v gh >/dev/null 2>&1; then
  echo "error: gh (GitHub CLI) is required but not found." >&2
  echo "Install it from https://cli.github.com and run \`gh auth login\` first." >&2
  exit 1
fi

os="$(uname -s)"
case "$os" in
  Darwin) os="darwin" ;;
  Linux)  os="linux"  ;;
  *)
    echo "error: unsupported OS: $os (supported: macOS, Linux)" >&2
    exit 1
    ;;
esac

arch="$(uname -m)"
case "$arch" in
  x86_64 | amd64)  arch="amd64" ;;
  arm64 | aarch64) arch="arm64" ;;
  *)
    echo "error: unsupported architecture: $arch (supported: amd64, arm64)" >&2
    exit 1
    ;;
esac

asset="rms-cli_${os}_${arch}"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

version_flag=""
if [ -n "${RMS_CLI_VERSION:-}" ]; then
  version_flag="--tag ${RMS_CLI_VERSION}"
fi

echo "Downloading ${asset}..."
# shellcheck disable=SC2086
gh release download ${version_flag} \
  --repo "$repo" \
  --pattern "$asset" \
  --dir "$tmp_dir"

chmod +x "${tmp_dir}/${asset}"

install_dir="${RMS_CLI_INSTALL_DIR:-/usr/local/bin}"
if [ ! -d "$install_dir" ] || [ ! -w "$install_dir" ]; then
  if [ -z "${RMS_CLI_INSTALL_DIR:-}" ] && command -v sudo >/dev/null 2>&1 && [ -d "$install_dir" ]; then
    echo "Installing to ${install_dir} requires administrator privileges."
    sudo mv "${tmp_dir}/${asset}" "${install_dir}/rms-cli"
    sudo chmod +x "${install_dir}/rms-cli"
  else
    install_dir="${HOME}/.local/bin"
    mkdir -p "$install_dir"
    mv "${tmp_dir}/${asset}" "${install_dir}/rms-cli"
  fi
else
  mv "${tmp_dir}/${asset}" "${install_dir}/rms-cli"
fi

echo ""
echo "rms-cli installed to ${install_dir}/rms-cli"

case ":${PATH}:" in
  *":${install_dir}:"*) ;;
  *)
    echo ""
    echo "NOTE: ${install_dir} is not on your PATH yet. Add this to your shell profile"
    echo "(~/.bashrc, ~/.zshrc, ~/.profile, etc.) and restart your terminal:"
    echo "  export PATH=\"${install_dir}:\$PATH\""
    ;;
esac

echo ""
"${install_dir}/rms-cli" --version || echo "warning: installed but couldn't run --version (see errors above)" >&2
echo ""
echo "Next: rms-cli auth login --profile <name> --service-secret <secret> --license-key <key>"
