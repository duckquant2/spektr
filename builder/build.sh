#!/usr/bin/env bash
# Сборка веб-версии выпуска «СПЕКТР» из markdown.
# Заголовок, номер и дата берутся из YAML-шапки самого .md (UTF-8) —
# поэтому кириллица больше не ломается (раньше она портилась при передаче
# через командную строку в Windows).
#
# Запускать из корня проекта (где лежат папки vypuski/ и builder/):
#   ./builder/build.sh                       # соберёт vypuski/spektr_vypusk_01.md
#   ./builder/build.sh spektr_vypusk_02.md   # соберёт указанный выпуск
# Исходники .md лежат в vypuski/, готовый .html появляется в html/.
set -euo pipefail

# Папка самого скрипта — там лежат шаблон и фильтры (исходник может быть в другой папке).
HERE="$(cd "$(dirname "$0")" && pwd)"

SRC_DIR="vypuski"   # папка с исходниками выпусков (.md)
OUT_DIR="html"      # папка с готовыми страницами (.html)

ARG="${1:-spektr_vypusk_01.md}"
BASE="$(basename "$ARG")"            # принимаем и имя файла, и путь
SRC="$SRC_DIR/$BASE"
OUT="$OUT_DIR/${BASE%.md}.html"

mkdir -p "$OUT_DIR"                   # папка сборки создаётся при необходимости

pandoc "$SRC" \
  --from markdown+autolink_bare_uris \
  --template "$HERE/spektr-web.html5" \
  --lua-filter "$HERE/spektr-filters.lua" \
  --section-divs \
  --metadata lang=ru \
  -o "$OUT"

echo "Готово: $OUT"
