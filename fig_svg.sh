#!/usr/bin/env bash
set -u

INPUT_DIR="${1:-.}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MACRO_FILE="$SCRIPT_DIR/q2_report/figure_export_macros.tex"

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

need_cmd xelatex
need_cmd pdf2svg

for texfile in "$INPUT_DIR"/*.tex; do
  [ -e "$texfile" ] || continue
  dir="$(dirname "$texfile")"
  base="$(basename "$texfile" .tex)"
  image="$dir/$base.svg"
  tmpdir="$(mktemp -d)"
  abs_tex="$(cd "$(dirname "$texfile")" && pwd)/$(basename "$texfile")"
  wrapper="$tmpdir/$base.tex"
  logfile="$tmpdir/$base.log"
  pdf="$tmpdir/$base.pdf"
  style_copy="$tmpdir/dsc180reportstyle.sty"

  sed 's/\\setmonofont\[Scale=0.9\]{Fira Code}/\\IfFontExistsTF{Fira Code}{\\setmonofont[Scale=0.9]{Fira Code}}{\\setmonofont{Menlo}}/' \
    "$SCRIPT_DIR/resources/style/dsc180reportstyle.sty" > "$style_copy"

  cat > "$wrapper" <<EOF
\documentclass[varwidth=true,border=2pt]{standalone}
\standaloneconfig{float=true}
\input{$MACRO_FILE}
\captionsetup{labelformat=empty}
\begin{document}
\input{$abs_tex}
\end{document}
EOF

  echo "Compiling $texfile"

  if ! TEXINPUTS="$tmpdir:$SCRIPT_DIR/resources/style:$SCRIPT_DIR/q2_report:${TEXINPUTS:-}" \
    xelatex -interaction=nonstopmode -halt-on-error -file-line-error \
    -output-directory "$tmpdir" "$wrapper" >"$logfile" 2>&1; then
    echo "Failed to compile $texfile" >&2
    echo "----- LaTeX log -----" >&2
    sed -n '1,200p' "$logfile" >&2
    echo "---------------------" >&2
    rm -rf "$tmpdir"
    continue
  fi

  if [ ! -f "$pdf" ]; then
    echo "Compilation reported success but no PDF was produced for $texfile" >&2
    echo "----- LaTeX log -----" >&2
    sed -n '1,200p' "$logfile" >&2
    echo "---------------------" >&2
    rm -rf "$tmpdir"
    continue
  fi

  if ! pdf2svg "$pdf" "$image"; then
    echo "Failed to convert PDF to SVG for $texfile" >&2
    rm -rf "$tmpdir"
    continue
  fi

  echo "Created $image"
  rm -rf "$tmpdir"
done