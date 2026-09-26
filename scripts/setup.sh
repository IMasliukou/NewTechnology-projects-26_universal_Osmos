#!/usr/bin/env bash
# Idempotent installer for the KiCad schematic toolchain.
# Safe to run repeatedly; only installs what is missing.
#
# We pin ONE KiCad version for the whole team so that local and cloud use the
# same file format (a schematic saved by a newer KiCad cannot be opened by an
# older one). By default we use the current STABLE release (10.0.x) from the
# official KiCad PPA, matching the stable KiCad on engineers' Windows machines.
# Override KICAD_PPA to switch streams, e.g.:
#   KICAD_PPA=kicad/kicad-9.0-releases  bash scripts/setup.sh   # previous stable
#   KICAD_PPA=kicad/kicad-10.0-nightly  bash scripts/setup.sh   # bleeding edge
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

# Official KiCad PPA to install from (stable 10.0.x by default).
KICAD_PPA="${KICAD_PPA:-kicad/kicad-10.0-releases}"

APT_PACKAGES=(
  kicad            # KiCad EDA suite (provides kicad-cli, eeschema, pcbnew)
  kicad-symbols    # Official schematic symbol libraries
  kicad-footprints # Official PCB footprint libraries
  poppler-utils    # pdftoppm: render exported PDFs to PNG previews
)

# Add the KiCad PPA once (add-apt-repository is idempotent).
if ! grep -rqs "kicad/${KICAD_PPA#kicad/}" /etc/apt/sources.list.d/ 2>/dev/null; then
  sudo add-apt-repository -y "ppa:${KICAD_PPA}"
fi

sudo apt-get update -qq
sudo apt-get install -y --no-install-recommends "${APT_PACKAGES[@]}"

# Seed the global symbol/footprint library tables so headless tools
# (kicad-cli sch erc, etc.) can resolve the standard KiCad libraries.
# The KiCad GUI normally creates these on first launch; we do it up front.
kicad_ver="$(kicad-cli version 2>/dev/null | cut -d. -f1-2)"   # e.g. "9.0"
cfg_dir="${HOME}/.config/kicad/${kicad_ver}"
tmpl_dir="/usr/share/kicad/template"
mkdir -p "$cfg_dir"
for tbl in sym-lib-table fp-lib-table; do
  if [ ! -f "${cfg_dir}/${tbl}" ] && [ -f "${tmpl_dir}/${tbl}" ]; then
    cp "${tmpl_dir}/${tbl}" "${cfg_dir}/${tbl}"
  fi
done

echo "KiCad toolchain ready:"
kicad-cli version
