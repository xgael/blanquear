#!/bin/bash
# Instala `blanquear` en ~/.local/bin y la Acción Rápida «Blanquear» en el Finder.
set -euo pipefail
AQUI=$(cd "$(dirname "$0")" && pwd)

command -v brew >/dev/null || { echo "Falta Homebrew: https://brew.sh" >&2; exit 1; }
brew install mat2 exiftool ffmpeg

mkdir -p "$HOME/.local/bin" "$HOME/Library/Services"
install -m 755 "$AQUI/bin/blanquear" "$AQUI/bin/blanquear-finder" "$HOME/.local/bin/"
rm -rf "$HOME/Library/Services/Blanquear.workflow"
cp -R "$AQUI/Blanquear.workflow" "$HOME/Library/Services/"
/System/Library/CoreServices/pbs -update

case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *)
  echo 'Agrega a tu ~/.zshrc:  export PATH="$HOME/.local/bin:$PATH"' ;;
esac
echo "Listo. Terminal: blanquear <carpeta>   ·   Finder: clic derecho → Acciones rápidas → Blanquear"
