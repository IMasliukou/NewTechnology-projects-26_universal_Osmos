#!/usr/bin/env bash
# Idempotent installer for the KiCad schematic toolchain.
# Safe to run repeatedly; only installs what is missing.
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

APT_PACKAGES=(
  kicad            # KiCad EDA suite (provides kicad-cli, eeschema, pcbnew)
  kicad-symbols    # Official schematic symbol libraries
  kicad-footprints # Official PCB footprint libraries
  poppler-utils    # pdftoppm: render exported PDFs to PNG previews
)

need_install=0
for pkg in "${APT_PACKAGES[@]}"; do
  if ! dpkg -s "$pkg" >/dev/null 2>&1; then
    need_install=1
    break
  fi
done

if [ "$need_install" -eq 1 ]; then
  sudo apt-get update -qq
  sudo apt-get install -y --no-install-recommends "${APT_PACKAGES[@]}"
else
  echo "All KiCad packages already installed; skipping apt install."
fi

echo "KiCad toolchain ready:"
kicad-cli version
