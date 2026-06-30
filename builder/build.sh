#!/usr/bin/env bash
# Сборка веб-версии выпуска «СПЕКТР» из markdown.
# Заголовок, номер и дата берутся из YAML-шапки самого .md (UTF-8) —
# поэтому кириллица больше не ломается (раньше она портилась при передаче
# через командную строку в Windows).
#
# Запускать из корня проекта (где лежат папки src/ и builder/):
#   ./builder/build.sh                       # соберёт src/spektr_vypusk_01.md
#   ./builder/build.sh spektr_vypusk_02.md   # соберёт указанный выпуск
#   ./builder/build.sh 2                      # то же по номеру выпуска
# Исходники .md лежат в src/, готовый выпуск появляется в dist/NN/ (NN — номер выпуска):
# index.html (самодостаточная страница) и spektr_vypusk_NN.pdf рядом.
# PDF — печать готового HTML через headless-браузер с системы (Edge/Chrome).
# Отключить генерацию PDF: SPEKTR_PDF=0 ./builder/build.sh
set -euo pipefail

# Папка самого скрипта — там лежат шаблон и фильтры (исходник может быть в другой папке).
HERE="$(cd "$(dirname "$0")" && pwd)"

SRC_DIR="src"       # папка с исходниками выпусков (.md)

ARG="${1:-spektr_vypusk_01.md}"
# Удобство: голый номер (`2`, `02`) достраиваем до имени файла выпуска.
if [[ "$ARG" =~ ^[0-9]+$ ]]; then
  ARG="$(printf 'spektr_vypusk_%02d.md' "$((10#$ARG))")"
fi
BASE="$(basename "$ARG")"            # принимаем и имя файла, и путь
SRC="$SRC_DIR/$BASE"

# Номер выпуска из имени файла (spektr_vypusk_01.md → 01) задаёт подпапку в dist/.
NN="${BASE#spektr_vypusk_}"; NN="${NN%.md}"
OUT_DIR="dist/$NN"                   # папка готового выпуска
OUT="$OUT_DIR/index.html"            # чистый URL /NN/ при публикации
PDF="$OUT_DIR/spektr_vypusk_$NN.pdf" # описательное имя — удобно при скачивании

mkdir -p "$OUT_DIR"                   # папка сборки создаётся при необходимости

pandoc "$SRC" \
  --from markdown+autolink_bare_uris \
  --template "$HERE/spektr-web.html5" \
  --lua-filter "$HERE/spektr-filters.lua" \
  --section-divs \
  --metadata lang=ru \
  -o "$OUT"

echo "Готово: $OUT"

# ---- PDF для печати (рядом с index.html в dist/NN/; SPEKTR_PDF=0 отключает) ----
# Готовый HTML уже содержит печатные стили (@media print, @page A4) — просто
# «распечатываем» его в PDF через headless-браузер, как при Ctrl+P в браузере.
# Путь к $PDF задан выше, рядом с $OUT.
if [ "${SPEKTR_PDF:-1}" != "0" ]; then
  BROWSER=""; HEADLESS="--headless=new"
  # 1) Изолированный chrome-headless-shell из кеша Playwright (не трогает профиль пользователя).
  SHELL_BIN="$(ls -d "$HOME"/AppData/Local/ms-playwright/chromium_headless_shell-*/chrome-headless-shell-win*/chrome-headless-shell.exe 2>/dev/null | head -1 || true)"
  if [ -n "$SHELL_BIN" ]; then
    BROWSER="$SHELL_BIN"; HEADLESS=""        # этот бинарь и так headless
  else
    # 2) Edge (есть на Windows 11), затем 3) Chrome.
    for c in \
      "/c/Program Files (x86)/Microsoft/Edge/Application/msedge.exe" \
      "/c/Program Files/Microsoft/Edge/Application/msedge.exe" \
      "/c/Program Files/Google/Chrome/Application/chrome.exe" \
      "/c/Program Files (x86)/Google/Chrome/Application/chrome.exe" \
      "$HOME/AppData/Local/Google/Chrome/Application/chrome.exe"; do
      [ -f "$c" ] && { BROWSER="$c"; break; }
    done
  fi

  if [ -n "$BROWSER" ]; then
    # Временный профиль — чтобы не задеть профиль пользователя и не упереться
    # в «браузер уже запущен»; пути конвертируем в Windows-вид для exe (cygpath).
    PROFILE="$(mktemp -d)"
    "$BROWSER" $HEADLESS --disable-gpu --no-pdf-header-footer \
      --user-data-dir="$(cygpath -w "$PROFILE")" \
      --print-to-pdf="$(cygpath -w -a "$PDF")" \
      "file:///$(cygpath -m -a "$OUT")" >/dev/null 2>&1 || true
    rm -rf "$PROFILE"
    if [ -f "$PDF" ]; then
      echo "Готово: $PDF"
    else
      echo "PDF не создан (браузер недоступен) — .html готов." >&2
    fi
  else
    echo "Chromium-браузер не найден — PDF пропущен, .html готов." >&2
  fi
fi

# ---- Главная страница сайта (архив выпусков) ----
# Освежаем dist/index.html со списком всех собранных выпусков — чтобы редактору
# не нужна была отдельная команда. Скрипт сканирует dist/NN/ и метаданные из src/.
"$HERE/build-index.sh"
