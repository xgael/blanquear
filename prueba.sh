#!/bin/bash
# Prueba de punta a punta: fabrica archivos con metadatos plantados (GPS, cámara, autor,
# URL de descarga, firmas del codificador), algunos sin extensión o con la equivocada,
# anidados en carpetas y zips; corre `blanquear` y exige:
#   1. ninguna etiqueta sensible (exiftool) y ningún valor plantado en los bytes
#   2. audio/video decodificado idéntico, cuadro por cuadro
#   3. misma estructura de carpetas, original intacto
#   4. lo que no se puede limpiar (zip con contraseña) queda fuera
# Uso: ./prueba.sh            (usa bin/blanquear de este repo)
set -u
export LC_ALL=C
AQUI=$(cd "$(dirname "$0")" && pwd); B="$AQUI/bin/blanquear"
T=$(mktemp -d); trap 'chmod -R u+rw "$T" 2>/dev/null; rm -rf "$T"' EXIT
fallas=0; check() { if eval "$2"; then echo "  ✓ $1"; else echo "  ✗ $1"; fallas=$((fallas+1)); fi; }
q() { ffmpeg -nostdin -loglevel error "$@"; }

echo "Fabricando muestras en $T…"
mkdir -p "$T/fx" "$T/C/nivel 2/nivel 3/nivel 4" "$T/C/vacía"
q -f lavfi -i testsrc=size=320x240 -frames:v 1 "$T/fx/f.jpg"
exiftool -q -overwrite_original -GPSLatitude=19.43 -GPSLatitudeRef=N -Make=Apple -Model="iPhone 15" \
  -Artist=PLANTADO -Software=Lightroom -Orientation#=6 "$T/fx/f.jpg"
sips -s format heic "$T/fx/f.jpg" --out "$T/fx/f.heic" >/dev/null
exiftool -q -overwrite_original -GPSLatitude=19.4 -GPSLatitudeRef=N -Model="iPhone 15" "$T/fx/f.heic"
echo "texto" > "$T/fx/n.txt"; textutil -convert docx -author PLANTADO "$T/fx/n.txt" -output "$T/fx/d.docx"
cupsfilter "$T/fx/n.txt" > "$T/fx/d.pdf" 2>/dev/null; exiftool -q -overwrite_original -Author=PLANTADO "$T/fx/d.pdf"
q -f lavfi -i testsrc=d=1:size=160x120 -f lavfi -i sine=d=1 -shortest -c:v libx264 -c:a aac \
  -metadata artist=PLANTADO "$T/fx/v.mp4"
cp "$T/fx/v.mp4" "$T/fx/v.mov"; exiftool -q -overwrite_original -Keys:GPSCoordinates="19.4, -99.1" -Keys:Model="iPhone 15" "$T/fx/v.mov"
q -f lavfi -i testsrc=d=1:size=160x120 -c:v libx265 -metadata title=PLANTADO "$T/fx/v.mkv" 2>/dev/null
q -f lavfi -i "sine=f=660:d=0.5" -c:a libmp3lame -metadata artist=PLANTADO "$T/fx/s.mp3"
FT="$(brew --prefix fonttools)/libexec/bin/python"
cp /System/Library/Fonts/Supplemental/Georgia.ttf "$T/fx/g.ttf"          # trae © Microsoft, fabricante, URLs
"$FT" -I -c "import sys; from fontTools.ttLib import TTFont; f=TTFont(sys.argv[1]); f.flavor='woff2'; f.save(sys.argv[2])" "$T/fx/g.ttf" "$T/fx/g.woff2"

cp "$T/fx/f.jpg" "$T/C/foto.jpg";           cp "$T/fx/f.jpg"  "$T/C/foto_sin_extension"
cp "$T/fx/d.pdf" "$T/C/nivel 2/papel.jpg";  cp "$T/fx/d.docx" "$T/C/nivel 2/documento"
cp "$T/fx/v.mov" "$T/C/nivel 2/nivel 3/clip"; cp "$T/fx/v.mkv" "$T/C/nivel 2/nivel 3/v.mkv"
cp "$T/fx/v.mp4" "$T/C/nivel 2/nivel 3/nivel 4/v.mp4"; cp "$T/fx/s.mp3" "$T/C/nivel 2/sonido.raro"
cp "$T/fx/f.heic" "$T/C/nivel 2/nivel 3/nivel 4/IMG_0001"
mkdir -p "$T/C/fuentes"; cp "$T/fx/g.ttf" "$T/C/fuentes/Georgia.ttf"; cp "$T/fx/g.woff2" "$T/C/fuentes/web_sin_extension"
cp "$T/fx/f.jpg" "$T/C/ilegible.jpg"; chmod 000 "$T/C/ilegible.jpg"   # como cuando macOS niega el permiso
(cd "$T/fx" && zip -q -j inner.zip f.jpg d.pdf && zip -q -j "$T/C/nivel 2/fotos.zip" f.heic inner.zip)
(cd "$T/fx" && zip -q -j -P clave "$T/C/cifrado.zip" f.jpg)
xattr -w com.apple.metadata:kMDItemWhereFroms "https://PLANTADO.example" "$T/C/foto.jpg"
head -c 2048 /dev/urandom > "$T/C/datos.xyz"; touch "$T/C/.DS_Store"
md5 -q "$T/C/foto.jpg" > "$T/md5"

echo "Corriendo blanquear…"
"$B" "$T/C" > "$T/log" 2>&1; rc=$?
O="$T/C (blanqueada)"
sed "s|$T/||" "$T/log" | sed 's/^/    /'

echo "Comprobaciones:"
check "termina con error (por el zip cifrado)" '[ $rc -ne 0 ]'
check "el zip cifrado no entra en la copia" '[ ! -e "$O/cifrado.zip" ]'
check "un archivo ilegible no deja copia sucia en el destino" '[ ! -e "$O/ilegible.jpg" ]'
check "el .DS_Store no entra en la copia" '[ ! -e "$O/.DS_Store" ]'
check "todo lo demás sí entra" '[ $(find "$O" -type f | wc -l) -eq $(find "$T/C" -type f ! -name ".*" ! -name cifrado.zip ! -name ilegible.jpg | wc -l) ]'
check "cada ✓/◦ del reporte existe en disco" '! sed -n "s/^[✓◦] \(.*\)$/\1/p" "$T/log" | sed "s/  (formato sin motor.*$//" | while IFS= read -r f; do [ -e "$f" ] || echo "$f"; done | grep -q .'
check "mismas carpetas (incluida la vacía)" 'diff <(cd "$T/C" && find . -type d | sort) <(cd "$O" && find . -type d | sort) >/dev/null'
check "original intacto" '[ "$(md5 -q "$T/C/foto.jpg")" = "$(cat "$T/md5")" ]'
check "tipos reales conservados (pdf llamado .jpg, docx sin extensión)" \
  '[ "$(file -b --mime-type "$O/nivel 2/papel.jpg")" = application/pdf ] && unzip -l "$O/nivel 2/documento" | grep -q word/document.xml'

X="$T/x"; mkdir -p "$X"; cp -R "$O/." "$X/"
for _ in 1 2 3; do  # abre zips dentro de zips (3 niveles bastan para estas muestras)
  find "$X" -name '*.zip' -print0 | while IFS= read -r -d '' z; do unzip -qq "$z" -d "$z.d"; rm -f "$z"; done
done
check "0 etiquetas sensibles (exiftool, zips abiertos)" \
  '[ $(exiftool -q -q -r -s -GPS:all -Make -Model -Artist -Author -Creator -Software -Title -GPSCoordinates "$X" 2>/dev/null | grep -vc "^=") -eq 0 ]'
check "0 valores plantados ni firmas de codificador en los bytes" \
  '! grep -rlaE "PLANTADO|iPhone|Lightroom|Lav[fc][0-9]+\.[0-9]|LAME[0-9]|x26[45] (- core|\(build)|FFMP" "$X" >/dev/null'
check "0 atributos extendidos (fuera de com.apple.provenance)" '[ $(find "$O" -type f -exec xattr {} + | grep -vc provenance) -eq 0 ]'
check "fuentes: sólo nombres funcionales, sin copyright/fabricante/URLs/metadatos WOFF" '"$FT" -I - "$O/fuentes/Georgia.ttf" "$O/fuentes/web_sin_extension" <<"PY2"
import sys
from fontTools.ttLib import TTFont
ok = True
for p in sys.argv[1:]:
    f = TTFont(p)
    ok &= {r.nameID for r in f["name"].names} <= {1, 2, 4, 6, 16, 17, 18, 20, 21, 22, 23, 24, 25}
    ok &= "DSIG" not in f and not f["OS/2"].achVendID.strip() and not (f.flavorData and f.flavorData.metaData)
sys.exit(0 if ok else 1)
PY2'
check "fuentes: dibujos de las letras idénticos al original" '"$FT" -I - "$T/C/fuentes/Georgia.ttf" "$O/fuentes/Georgia.ttf" "$T/C/fuentes/web_sin_extension" "$O/fuentes/web_sin_extension" <<"PY2"
import sys
from fontTools.ttLib import TTFont
a = sys.argv[1:]; ok = True
for o, c in zip(a[::2], a[1::2]):
    fo, fc = TTFont(o), TTFont(c)
    for t in ("glyf", "loca", "cmap", "hmtx", "kern", "GPOS", "GSUB", "fpgm", "prep", "cvt "):
        if t in fo: ok &= fo[t].compile(fo) == fc[t].compile(fc)
sys.exit(0 if ok else 1)
PY2'
check "orientación de la foto conservada" '[ "$(exiftool -s3 -Orientation "$O/foto.jpg")" = "Rotate 90 CW" ]'
iguales=1
for r in "nivel 2/nivel 3/clip" "nivel 2/nivel 3/v.mkv" "nivel 2/nivel 3/nivel 4/v.mp4" "nivel 2/sonido.raro"; do
  a=$(ffmpeg -nostdin -loglevel error -i "$T/C/$r" -map 0 -f framemd5 - | grep -v '^#' | md5 -q)
  b=$(ffmpeg -nostdin -loglevel error -i "$O/$r" -map 0 -f framemd5 - | grep -v '^#' | md5 -q)
  [ "$a" = "$b" ] || { iguales=0; echo "    distinto: $r"; }
done
check "audio/video decodificado idéntico cuadro por cuadro" '[ $iguales -eq 1 ]'
check "foto idéntica en píxeles" '[ "$(ffmpeg -nostdin -i "$T/C/foto.jpg" -i "$O/foto.jpg" -lavfi ssim -f null - 2>&1 | grep -o "All:[0-9.]*")" = "All:1.000000" ]'

echo "Destino renombrado a media corrida…"
R="$T/R"; mkdir -p "$R"; for i in $(seq 1 200); do cp "$T/fx/g.ttf" "$R/g$i.ttf"; done
"$B" "$R" > "$T/logR" 2>&1 & pid=$!
until [ -n "$(ls "$R (blanqueada)" 2>/dev/null)" ] || ! kill -0 $pid 2>/dev/null; do sleep 0.1; done
mv "$R (blanqueada)" "$T/R renombrada"; wait $pid; rcR=$?
check "termina con error" '[ $rcR -ne 0 ]'
check "avisa que el destino desapareció" 'grep -q "desapareció a media corrida" "$T/logR"'
check "ningún ✓ apunta a un archivo que no existe" '! sed -n "s/^✓ \(.*\)$/\1/p" "$T/logR" | sed "s|$R (blanqueada)|$T/R renombrada|" | while IFS= read -r f; do [ -e "$f" ] || echo "$f"; done | grep -q .'
check "no imprime «carpeta limpia» de una carpeta que ya no existe" '! grep -q "^→ carpeta limpia" "$T/logR"'

echo; [ $fallas -eq 0 ] && echo "TODO BIEN" || echo "$fallas comprobación(es) fallaron"
exit $fallas
