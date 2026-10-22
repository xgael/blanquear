# blanquear

Quita los metadatos de tus archivos (ubicación GPS, cámara, autor, software, fechas internas,
«descargado de», firmas del programa que los creó) y **verifica** que no quede nada antes de
darlos por limpios. macOS.

```bash
./instalar.sh                      # mat2 + exiftool + ffmpeg (brew), comando y Acción Rápida
blanquear ~/Desktop/Mi\ carpeta    # → «Mi carpeta (blanqueada)» al lado, misma estructura
```

O en el Finder: clic derecho sobre archivos o carpetas → **Acciones rápidas → Blanquear**.
Avisa al terminar y muestra el resultado; el reporte queda en `~/Library/Logs/blanquear.log`.

## Qué hace

| Entrada | Salida |
|---|---|
| carpeta | `Carpeta (blanqueada)` al lado: mismas subcarpetas (todos los niveles) y nombres; el original no se toca |
| archivo | `nombre.cleaned.ext` al lado |
| `--en-sitio` | sobrescribe los originales (sin respaldo) |
| `--ligero` | PDF con texto seleccionable (por defecto cada página se vuelve imagen: lo único que garantiza un PDF vacío) |

El tipo se reconoce por el **contenido**, no por la terminación: una foto sin extensión o un
PDF llamado `.jpg` se limpian con el motor correcto y conservan su nombre.

| Tipo | Motor |
|---|---|
| Fotos (jpg, png, heic, tiff, webp, dng) | exiftool, **sin re-codificar** (se conservan orientación y perfil de color) |
| MOV / MP4 / M4A | exiftool, sin re-empaquetar |
| Documentos, PDF, audio (docx, xlsx, pptx, odt, pdf, mp3, flac, wav…) | mat2 |
| Resto de audio/video (mkv, webm, avi…) | ffmpeg `-c copy`, sin re-codificar |
| ZIP | se abre y su contenido se blanquea con este mismo comando (zips dentro de zips incluidos) |
| Cualquier otro | exiftool si sabe escribirlo; si nadie puede, se copia tal cual **sólo si** no se le hallan metadatos (`◦`) |

Además: atributos extendidos de macOS (cuarentena, `kMDItemWhereFroms`, etiquetas) y las
**firmas del codificador dentro del audio/video** que ninguna herramienta de metadatos ve
(`LAME4.0`, `Lavc63.1.102`, opciones de x264/x265, `FFMP`), reemplazadas por relleno del mismo
largo. En MP3 la cabecera LAME conserva sus 4 letras: los reproductores (CoreAudio sólo con
«LAME») las usan para recortar el silencio del inicio.

## Cómo se lee el resultado

- `✓` limpio y verificado (exiftool + ffprobe + búsqueda de firmas en los bytes)
- `◦` formato sin metadatos conocidos: copiado tal cual
- `⚠` quedó algo (se lista) · `✗` no se pudo limpiar → **no entra en la copia**

Termina con código ≠ 0 si algo quedó fuera.

## Lo que no hace

- No toca el **contenido**: un nombre escrito en el documento o una cara en la foto siguen ahí.
- No copia archivos ni carpetas **ocultos** (`.DS_Store`, `.git`…).
- Un **zip con contraseña** no se puede abrir: queda fuera (`✗`).
- En **MP3** queda la palabra «Lavf/Lavc/LAME» sin versión (quitarla cambia el audio en Apple).
- `com.apple.provenance` lo pone macOS y no se puede borrar; no viaja con el archivo.
- Las fechas del sistema de archivos de la copia son las de hoy (no se falsean).

## Prueba

```bash
./prueba.sh
```

Fabrica archivos con metadatos plantados (GPS, iPhone, autor, URL de descarga, firmas de
x264/x265/LAME), anidados en carpetas y zips, con y sin extensión; corre `blanquear` y exige
0 etiquetas sensibles, 0 valores plantados en los bytes, audio/video decodificado idéntico
cuadro por cuadro, foto idéntica en píxeles, misma estructura y original intacto.
