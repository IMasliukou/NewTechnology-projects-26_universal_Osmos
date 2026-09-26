#!/usr/bin/env bash
# Reproducible, headless export of KiCad schematics to review artifacts.
#
# This is an electrical/control-schematic workflow (automation projects):
# only schematics matter, there is no PCB. We therefore export schematic
# review artifacts only (no footprints/gerbers/DRC).
#
# For each schematic it produces, under output/<project>/:
#   - <project>.pdf   : printable schematic
#   - <project>.svg   : vector schematic (good for diffs / web review)
#   - <project>.net   : KiCad netlist (wiring / connection list)
#   - <project>.bom.csv : Bill of Materials (component list, grouped by value)
#   - <project>.erc   : Electrical Rules Check report (KiCad 8+)
#   - <project>.png   : raster preview (if pdftoppm is available)
#
# Usage:
#   scripts/export.sh                       # export every project under projects/
#   scripts/export.sh projects/my-project   # export a single project directory
#   scripts/export.sh path/to/file.kicad_sch
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_ROOT="${REPO_ROOT}/output"

if ! command -v kicad-cli >/dev/null 2>&1; then
  echo "ERROR: kicad-cli not found. Run scripts/setup.sh first." >&2
  exit 1
fi

collect_schematics() {
  local target="$1"
  if [ -f "$target" ]; then
    printf '%s\n' "$target"
  elif [ -d "$target" ]; then
    find "$target" -name '*.kicad_sch' | sort
  fi
}

targets=()
if [ "$#" -eq 0 ]; then
  targets+=("${REPO_ROOT}/projects")
else
  targets+=("$@")
fi

schematics=()
for t in "${targets[@]}"; do
  while IFS= read -r line; do
    [ -n "$line" ] && schematics+=("$line")
  done < <(collect_schematics "$t")
done

if [ "${#schematics[@]}" -eq 0 ]; then
  echo "No .kicad_sch files found for: ${targets[*]}" >&2
  exit 1
fi

for sch in "${schematics[@]}"; do
  name="$(basename "$sch" .kicad_sch)"
  outdir="${OUT_ROOT}/${name}"
  mkdir -p "$outdir"
  echo "==> Exporting ${name}"

  kicad-cli sch export pdf     --output "${outdir}/${name}.pdf" "$sch"
  kicad-cli sch export svg     --output "${outdir}"             "$sch"
  kicad-cli sch export netlist --output "${outdir}/${name}.net" "$sch"
  kicad-cli sch export bom \
    --fields 'Reference,Value,${QUANTITY}' \
    --labels 'Refs,Value,Qty' \
    --group-by Value \
    --output "${outdir}/${name}.bom.csv" "$sch"

  # Electrical Rules Check (available since KiCad 8). Report is saved even when
  # violations exist; we surface the summary line but do not fail the export.
  if kicad-cli sch erc --help >/dev/null 2>&1; then
    kicad-cli sch erc --output "${outdir}/${name}.erc" "$sch" >/dev/null 2>&1 || true
    if [ -f "${outdir}/${name}.erc" ]; then
      grep -E "ERC messages" "${outdir}/${name}.erc" | sed 's/^/    ERC: /' || true
    fi
  fi

  if command -v pdftoppm >/dev/null 2>&1; then
    pdftoppm -png -r 150 -singlefile "${outdir}/${name}.pdf" "${outdir}/${name}" >/dev/null 2>&1 || true
  fi

  echo "    -> ${outdir}"
done

echo "Done. Artifacts written under ${OUT_ROOT}/"
