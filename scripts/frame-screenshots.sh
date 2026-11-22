#!/usr/bin/env bash
# Render framed 1320x2868 App Store screenshots from marketing/screenshots/raw.
# Output: marketing/screenshots/<lang>/<n>.png (6 per language), n follows the listing caption order.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

CHROME="${CHROME:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
[[ -x "$CHROME" ]] || { echo "Chrome not found at $CHROME (set CHROME=...)" >&2; exit 1; }
W=1320; H=2868
TEMPLATE="$ROOT/marketing/frames/template.html"

# Listing order -> raw scene.
SCENE_FOR=(swipe trash undo favorite privacy celebration)
caps_en=("Swipe. Keep. Delete. Done." "See what you'll clear" "Oops? Undo it" "Swipe up to favorite ★" "Private. On your iPhone." "Nice work. Pile cleared!")
caps_es=("Desliza, guarda, borra" "Mira cuánto vas a limpiar" "¿Te arrepientes? Deshaz" "Arriba para favoritas ★" "Privado, en tu iPhone" "¡Buen trabajo! Pila lista")

urlenc() { # percent-encode every byte that is not unreserved (pure bash, byte-wise)
  local LC_ALL=C s="$1" out="" c i
  for ((i = 0; i < ${#s}; i++)); do
    c="${s:i:1}"
    case "$c" in [a-zA-Z0-9.~_-]) out+="$c" ;; *) out+="$(printf '%%%02X' "'$c")" ;; esac
  done
  printf '%s\n' "$out"
}

for lang in en es; do
  mkdir -p "marketing/screenshots/$lang"
  if [[ "$lang" == en ]]; then caps=("${caps_en[@]}"); else caps=("${caps_es[@]}"); fi
  for i in 0 1 2 3 4 5; do
    n=$((i + 1)); scene="${SCENE_FOR[$i]}"
    raw="$(find "marketing/screenshots/raw/$lang" -maxdepth 1 -name "*-$scene.png" | sort | head -1)"
    [[ -n "$raw" ]] || { echo "Missing raw capture for $lang/$scene; run scripts/screenshots.sh" >&2; exit 1; }
    out="$ROOT/marketing/screenshots/$lang/$n.png"
    url="file://$TEMPLATE?img=$(urlenc "file://$ROOT/$raw")&cap=$(urlenc "${caps[$i]}")&lang=$lang"
    "$CHROME" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1 \
      --virtual-time-budget=4000 --allow-file-access-from-files \
      --window-size="$W,$H" --screenshot="$out" "$url" >/dev/null 2>&1
    dims="$(sips -g pixelWidth -g pixelHeight "$out" | awk '/pixel/ {printf "%s ", $2}')"
    [[ "$dims" == "$W $H " ]] || { echo "Wrong size for $out: $dims(expected $W $H)" >&2; exit 1; }
    echo "$out  ${W}x${H}"
  done
done
