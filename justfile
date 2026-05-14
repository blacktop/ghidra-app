set shell := ["bash", "-euo", "pipefail", "-c"]

ghidra_repo := "NationalSecurityAgency/ghidra"
this_repo := "blacktop/ghidra-app"
cask_file := env_var('HOME') + "/Developer/Mine/blacktop/homebrew-tap/Casks/ghidra-app.rb"
workflow := ".github/workflows/build.yml"

# Default: list recipes
default:
    @just --list

# Show the latest upstream Ghidra release
latest:
    @gh release view --repo {{ ghidra_repo }} --json tagName,name -q '"\(.name)  [\(.tagName)]"'

# Bump Ghidra version: update build.yml, commit, push, cut placeholder release
# Usage: just bump            # auto-detect latest from upstream
# just bump 12.1       # explicit version
bump version="":
    #!/usr/bin/env bash
    set -euo pipefail

    if [ -z "{{ version }}" ]; then
      tag=$(gh release view --repo {{ ghidra_repo }} --json tagName -q '.tagName')
      ver=${tag#Ghidra_}
      ver=${ver%_build}
    else
      ver="{{ version }}"
      tag="Ghidra_${ver}_build"
    fi
    echo "==> Bumping to Ghidra ${ver} (upstream tag: ${tag})"

    current=$(grep -E '^\s+ref: Ghidra_.+_build' {{ workflow }} | sed -E 's/.*ref: (Ghidra_.+_build).*/\1/')
    if [ "${current}" = "${tag}" ]; then
      echo "==> {{ workflow }} already pinned to ${tag}; nothing to do."
      exit 0
    fi

    sed -i.bak -E "s|ref: Ghidra_[^[:space:]]+_build|ref: ${tag}|" {{ workflow }}
    rm {{ workflow }}.bak

    echo
    git diff -- {{ workflow }}
    echo

    read -rp "Commit, push, and cut placeholder release v${ver}? [y/N] " ans
    case "${ans}" in
      y|Y|yes|YES) ;;
      *) echo "Aborted. Edits left on disk."; exit 1 ;;
    esac

    git add {{ workflow }}
    git commit -m "chore: ${ver}"
    git push origin main

    if gh release view "v${ver}" --repo {{ this_repo }} >/dev/null 2>&1; then
      echo "==> Release v${ver} already exists; CI will overwrite assets."
    else
      gh release create "v${ver}" \
        --repo {{ this_repo }} \
        --title "v${ver}" \
        --notes "Build in progress — assets populated by CI."
    fi

    echo "==> Done. Track build: gh run watch --repo {{ this_repo }}"

# Update the homebrew-tap cask to match the latest published release.
# Edits the file in-place and shows a diff; commit/push from the tap repo.
# Usage: just bump-cask         # use latest blacktop/ghidra-app release
# just bump-cask 12.1
bump-cask version="":
    #!/usr/bin/env bash
    set -euo pipefail

    if [ -z "{{ version }}" ]; then
      ver=$(gh release view --repo {{ this_repo }} --json tagName -q '.tagName' | sed 's/^v//')
    else
      ver="{{ version }}"
    fi
    echo "==> Updating cask for Ghidra ${ver}"

    cask={{ cask_file }}
    if [ ! -f "${cask}" ]; then
      echo "Cask not found: ${cask}" >&2
      exit 1
    fi

    sha_url="https://github.com/{{ this_repo }}/releases/download/v${ver}/Ghidra_${ver}.zip.sha256"
    sha=$(curl -fsSL "${sha_url}" | awk '{print $1}' | head -c 64)
    if [ "${#sha}" -ne 64 ]; then
      echo "Failed to fetch sha256 from ${sha_url}" >&2
      exit 1
    fi
    echo "    sha256: ${sha}"

    sed -i.bak -E "s|^  version \".*\"|  version \"${ver},0\"|" "${cask}"
    sed -i.bak -E "s|^  sha256 \".*\"|  sha256 \"${sha}\"|" "${cask}"
    rm "${cask}.bak"

    echo
    git -C "$(dirname "${cask}")/.." diff -- "${cask}"
    echo "==> Cask updated. Review, commit, and push from the homebrew-tap repo."
