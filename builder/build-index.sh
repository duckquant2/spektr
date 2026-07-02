#!/usr/bin/env bash
# Генератор главной страницы сайта «СПЕКТР» — архива выпусков (dist/index.html).
# Сканирует готовые выпуски в dist/NN/ и для каждого берёт метаданные из YAML-шапки
# исходника src/spektr_vypusk_NN.md (issue, date, date-human, description). Выводит
# самодостаточный index.html со списком ссылок на выпуски (свежие сверху).
#
# Запускать из корня проекта (где лежат src/ и dist/):
#   ./builder/build-index.sh
# Обычно вызывается автоматически в конце builder/build.sh.
#
# Кириллица берётся из файлов в UTF-8, а НЕ из аргументов командной строки —
# так же, как в build.sh (иначе ломается на Windows). Файлы .md обязаны быть в UTF-8.
set -euo pipefail

SRC_DIR="src"
DIST_DIR="dist"
OUT="$DIST_DIR/index.html"

# --- Достать значение поля из YAML-шапки .md (между первыми --- ... ---) -------
# Разбор по структуре строк, без Unicode-небезопасных паттернов: режем только
# ASCII-кавычки и пробелы, само значение (кириллица) не трогаем.
yaml_field() {
  awk -v key="$2" '
    NR==1 && $0=="---" { infm=1; next }
    infm && $0=="---"  { exit }
    infm {
      idx = index($0, ":")
      if (idx > 0) {
        k = substr($0, 1, idx-1)
        gsub(/^[ \t]+|[ \t]+$/, "", k)
        if (k == key) {
          v = substr($0, idx+1)
          gsub(/^[ \t]+|[ \t]+$/, "", v)   # обрезать пробелы по краям
          gsub(/^"|"$/, "", v)             # снять обрамляющие кавычки
          print v
          exit
        }
      }
    }
  ' "$1"
}

# --- Экранирование для HTML-текста ---------------------------------------------
html_escape() {
  printf '%s' "$1" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'
}

# --- Собрать карточки выпусков (свежие сверху) ---------------------------------
# Номера подпапок dist/NN/ с index.html, отсортированные по убыванию (10#NN — без
# восьмеричной ловушки ведущего нуля).
NUMS="$(
  for d in "$DIST_DIR"/*/; do
    nn="$(basename "$d")"
    [[ "$nn" =~ ^[0-9]+$ ]] || continue
    [ -f "$d/index.html" ] || continue
    printf '%s\n' "$nn"
  done | sort -rn
)"

CARDS=""
for NN in $NUMS; do
  SRC="$SRC_DIR/spektr_vypusk_$NN.md"
  if [ -f "$SRC" ]; then
    issue="$(yaml_field "$SRC" issue)"
    date_iso="$(yaml_field "$SRC" date)"
    date_human="$(yaml_field "$SRC" date-human)"
    descr="$(yaml_field "$SRC" description)"
  else
    issue=""; date_iso=""; date_human=""; descr=""
  fi
  # Номер выпуска: из YAML, иначе из имени папки (без ведущего нуля).
  [ -n "$issue" ] || issue="$((10#$NN))"

  title="$(html_escape "Выпуск №$issue")"
  descr_html="$(html_escape "$descr")"
  date_html="$(html_escape "$date_human")"

  CARDS+="<li class=\"issue\">"
  CARDS+="<a class=\"issue-link\" href=\"$NN/\">"
  CARDS+="<span class=\"issue-no\">$title</span>"
  if [ -n "$date_html" ]; then
    CARDS+="<time class=\"issue-date\" datetime=\"$date_iso\">$date_html</time>"
  fi
  if [ -n "$descr_html" ]; then
    CARDS+="<span class=\"issue-descr\">$descr_html</span>"
  fi
  CARDS+="</a></li>"$'\n'
done

# --- Записать страницу ---------------------------------------------------------
# Стиль повторяет дизайн-токены шаблона spektr-web.html5 (фирменный спектр,
# системные шрифты, светлая/тёмная тема). Страница самодостаточна, без внешних
# зависимостей — как и выпуски.
cat > "$OUT" <<HTML
<!DOCTYPE html>
<html lang="ru">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="color-scheme" content="light dark">
<title>СПЕКТР · Научно-популярный журнал об аутизме · Архив выпусков</title>
<meta name="description" content="СПЕКТР — научно-популярный журнал об аутизме для родителей. Архив всех выпусков.">
<meta name="author" content="Редакция «СПЕКТРА»">
<link rel="icon" href="data:image/svg+xml,%3Csvg%20xmlns%3D%22http%3A%2F%2Fwww.w3.org%2F2000%2Fsvg%22%20viewBox%3D%220%200%2016%2016%22%3E%3Crect%20width%3D%2216%22%20height%3D%2216%22%20fill%3D%22%23fff%22%2F%3E%3Crect%20y%3D%222%22%20width%3D%2216%22%20height%3D%221.5%22%20fill%3D%22%23e4572e%22%2F%3E%3Crect%20y%3D%223.5%22%20width%3D%2216%22%20height%3D%221.5%22%20fill%3D%22%23f4a83a%22%2F%3E%3Crect%20y%3D%225%22%20width%3D%2216%22%20height%3D%221.5%22%20fill%3D%22%23f5d23c%22%2F%3E%3Crect%20y%3D%226.5%22%20width%3D%2216%22%20height%3D%221.5%22%20fill%3D%22%234caf6d%22%2F%3E%3Crect%20y%3D%228%22%20width%3D%2216%22%20height%3D%221.5%22%20fill%3D%22%231aa3b0%22%2F%3E%3Crect%20y%3D%229.5%22%20width%3D%2216%22%20height%3D%221.5%22%20fill%3D%22%233b6fd1%22%2F%3E%3Crect%20y%3D%2211%22%20width%3D%2216%22%20height%3D%221.5%22%20fill%3D%22%238a4fd0%22%2F%3E%3Crect%20y%3D%2212.5%22%20width%3D%2216%22%20height%3D%221.5%22%20fill%3D%22%23e4572e%22%2F%3E%3C%2Fsvg%3E">
<meta property="og:type" content="website">
<meta property="og:locale" content="ru_RU">
<meta property="og:site_name" content="СПЕКТР">
<meta property="og:title" content="СПЕКТР · Архив выпусков">
<style>
  /* ============ ДИЗАЙН-ТОКЕНЫ (как в spektr-web.html5) ============ */
  :root{
    --ink:#181a1f; --body:#2b2e34; --muted:#6c7178; --rule:#e6e6e2;
    --paper:#ffffff; --card:#eef6f6;
    --accent:#0e7490; --accent-2:#3b4f9e; --accent-ink:#0a5566;
    --spectrum-stops:
      #e4572e 0%, #f4a83a 17%, #f5d23c 33%, #4caf6d 50%,
      #1aa3b0 67%, #3b6fd1 83%, var(--accent-2) 100%;
    --serif: Georgia, "PT Serif", "Noto Serif", "Times New Roman", serif;
    --sans: system-ui, -apple-system, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
    --measure: 40rem;
  }
  @media (prefers-color-scheme: dark){
    :root{
      --ink:#f0efec; --body:#dcdad4; --muted:#9a958c; --rule:#33322f;
      --paper:#15161a; --card:#16262b;
      --accent:#5fb3c4; --accent-2:#9aa8e6; --accent-ink:#8fd0dd;
    }
  }
  *{ box-sizing:border-box; }
  html{ -webkit-text-size-adjust:100%; overflow-x:hidden; }
  body{
    margin:0; background:var(--paper); color:var(--body);
    font-family:var(--serif);
    font-size: clamp(1.0625rem, 1rem + 0.35vw, 1.1875rem);
    line-height:1.7; text-rendering:optimizeLegibility;
    -webkit-font-smoothing:antialiased; overflow-wrap:break-word;
  }
  .page{ max-width:var(--measure); margin:0 auto; padding:2.2rem 1.25rem 4rem; }

  h1{
    position:relative; padding-left:.85rem;
    font-family:var(--sans); font-weight:800; color:var(--ink);
    font-size: clamp(2.6rem, 11vw, 4.4rem); line-height:.95;
    letter-spacing:-.02em; margin:0 0 .15em;
  }
  h1::before{
    content:""; position:absolute; left:0; top:.15em; height:.75em;
    width:6px; background:linear-gradient(180deg, var(--spectrum-stops));
  }
  h1 + .deck{
    font-family:var(--sans); font-weight:700; text-transform:uppercase;
    letter-spacing:.08em; font-size:.78rem; color:var(--accent);
    margin:.2rem 0 1.2rem;
  }
  hr{ border:0; height:1px; background:var(--rule); margin:1.8rem 0; }
  .lead{ margin:0 0 2rem; }

  h2{
    font-family:var(--sans); font-weight:800; color:var(--ink);
    font-size: clamp(1.5rem, 5vw, 2.05rem); line-height:1.1;
    letter-spacing:-.01em; margin:2.6rem 0 1.4rem; padding-top:1rem;
    border-top:3px solid var(--accent);
  }

  /* ============ СПИСОК ВЫПУСКОВ ============ */
  .issues{ list-style:none; margin:0; padding:0; }
  .issue{ margin:0 0 1rem; }
  .issue-link{
    display:block; padding:1.1rem 1.3rem;
    background:var(--card); border-left:3px solid var(--accent);
    border-radius:4px; color:var(--body); text-decoration:none;
    transition:transform .15s ease, box-shadow .15s ease;
  }
  .issue-link:hover, .issue-link:focus-visible{
    box-shadow:0 6px 18px color-mix(in srgb, var(--ink) 14%, transparent);
    transform:translateY(-1px);
  }
  .issue-link:focus-visible{ outline:2px solid var(--accent); outline-offset:2px; }
  .issue-no{
    display:block; font-family:var(--sans); font-weight:800; color:var(--ink);
    font-size:1.3rem; line-height:1.1; letter-spacing:-.01em;
  }
  .issue-date{
    display:block; font-family:var(--sans); font-size:.82rem; color:var(--muted);
    margin:.25rem 0 0;
  }
  .issue-descr{ display:block; font-size:.97rem; margin:.55rem 0 0; }

  .empty{ color:var(--muted); font-style:italic; }
  .colophon{ font-family:var(--sans); font-size:.85rem; color:var(--muted); }

  @media (max-width:560px){
    .page{ padding:1.8rem 1.05rem 3rem; }
  }
</style>
</head>
<body>
<main class="page">
<header>
<h1>СПЕКТР</h1>
<p class="deck">Научно-популярный журнал об аутизме</p>
<p class="lead">Для родителей, специалистов и всех, кому это важно. Новости, свежие исследования и живые истории. За каждым фактом — ссылка на источник. Новый выпуск каждый месяц.</p>
</header>
<h2>Архив выпусков</h2>
HTML

if [ -n "$CARDS" ]; then
  printf '<ol class="issues">\n%s</ol>\n' "$CARDS" >> "$OUT"
else
  printf '<p class="empty">Выпусков пока нет.</p>\n' >> "$OUT"
fi

cat >> "$OUT" <<'HTML'
<hr>
<footer class="colophon">
<p><em>«СПЕКТР» — научно-популярный журнал об аутизме. Материалы носят информационный характер и не заменяют консультацию специалиста.</em></p>
</footer>
</main>
</body>
</html>
HTML

echo "Готово: $OUT"
