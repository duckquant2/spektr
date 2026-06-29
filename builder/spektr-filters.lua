-- Фильтры pandoc для веб-версии «СПЕКТРА».
-- Превращают обычный markdown в семантику понравившегося макета:
-- таблицы со скроллом, заголовки-лиды, кикеры, врезки-callout и подписи цитат.

-- ── Экранирование для сырого HTML (имена/роли в подписях) ──────────────
local function esc(s)
  return (s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

-- ── Таблицу оборачиваем в <div class="table-scroll"> ───────────────────
-- (горизонтальная прокрутка на узких экранах; содержимое не меняется)
function Table(el)
  return pandoc.Div({ el }, pandoc.Attr("", { "table-scroll" }))
end

-- ── Кикер: КАПС-строка с «·» сразу под заголовком новости ──────────────
-- Напр. «РОССИЯ · клинические рекомендации» → <p class="kicker">.
-- Проверяем структуру инлайнов (а не байтовый поиск «·», который не
-- Unicode-безопасен в Lua-паттернах и режет кириллицу).
local function is_kicker(b)
  if b.t ~= "Para" then return false end
  local inl = b.content
  if #inl < 3 then return false end
  local first = inl[1]
  if first.t ~= "Str" then return false end             -- первое слово — капсом
  if pandoc.text.len(first.text) < 3 then return false end
  if pandoc.text.upper(first.text) ~= first.text then return false end
  local has_sep = false                                  -- есть разделитель «·»
  for _, x in ipairs(inl) do
    if x.t == "Str" and x.text == "·" then has_sep = true; break end
  end
  if not has_sep then return false end
  return pandoc.text.len(pandoc.utils.stringify(b)) <= 80  -- кикер короткий
end

-- ── Абзац ровно из одного жирного фрагмента → заголовок-лид h4 ──────────
local function bold_only_header(b)
  if b.t == "Para" and #b.content == 1 and b.content[1].t == "Strong" then
    return pandoc.Header(4, b.content[1].content)
  end
  return nil
end

-- Обрабатываем список блоков, чтобы видеть соседей (кикер = после заголовка).
function Blocks(blocks)
  local out = {}
  for _, b in ipairs(blocks) do
    local prev = out[#out]
    local h4 = bold_only_header(b)
    if h4 then
      out[#out + 1] = h4
    elseif prev and prev.t == "Header" and is_kicker(b) then
      -- Plain вместо Para — чтобы вышло <div class="kicker">текст</div> без вложенного <p>
      out[#out + 1] = pandoc.Div(pandoc.Plain(b.content), pandoc.Attr("", { "kicker" }))
    else
      out[#out + 1] = b
    end
  end
  return out
end

-- ── Подпись цитаты: хвостовая строка, начинающаяся с тире ───────────────
-- Цитата вида «> текст\n> — Имя, роль» приходит одним Para с разрывом строки.
-- Отделяем строку после разрыва, если она начинается с тире.
local function starts_with_dash(s)
  return s == "—" or s == "–" or s == "-"
end

local function split_attribution(para)
  local c = para.content
  for i = 1, #c do
    if c[i].t == "SoftBreak" or c[i].t == "LineBreak" then
      local nxt = c[i + 1]
      if nxt and nxt.t == "Str" and starts_with_dash(nxt.text) then
        local before, after = {}, {}
        for j = 1, i - 1 do before[#before + 1] = c[j] end
        for j = i + 1, #c do after[#after + 1] = c[j] end
        return before, after          -- after — список инлайнов (Unicode цел)
      end
    end
  end
  return c, nil
end

-- Строит <footer class="attribution">— <cite>Имя</cite>, роль…</footer>.
-- Тире берём из инлайна целиком; режем имя/роль только по ASCII («,» или «(»),
-- которые не встречаются внутри многобайтовых кириллических символов.
local function make_footer(after)
  local dash = after[1] and after[1].text or "—"
  local rest_inls = {}
  for j = 2, #after do rest_inls[#rest_inls + 1] = after[j] end
  local rest = pandoc.utils.stringify(pandoc.Inlines(rest_inls)):gsub("^%s+", "")
  local name, tail = rest:match("^([^,(]*)(.*)$")
  if not name then name, tail = rest, "" end
  name = name:gsub("%s+$", "")
  -- вернуть пробел перед скобкой «(перевод…)», срезанный при тримминге имени
  if tail ~= "" and tail:sub(1, 1) == "(" then tail = " " .. tail end
  local html = '<footer class="attribution">' .. esc(dash) .. " "
    .. "<cite>" .. esc(name) .. "</cite>" .. esc(tail) .. "</footer>"
  return pandoc.RawBlock("html", html)
end

-- ── Цитата vs врезка-пояснение ─────────────────────────────────────────
-- Цитата `>`, начинающаяся с жирного зачина (или ставшая h4-лидом), —
-- это пояснительная врезка → <div class="callout">.
-- Обычная цитата человека остаётся <blockquote>, а её последняя строка
-- «— Имя…» выносится в подпись.
function BlockQuote(el)
  local first = el.content[1]
  local is_callout = first ~= nil and (
    first.t == "Header"
    or (first.content and first.content[1] and first.content[1].t == "Strong")
  )
  if is_callout then
    return pandoc.Div(el.content, pandoc.Attr("", { "callout" }))
  end

  local blocks = {}
  for _, b in ipairs(el.content) do
    if b.t == "Para" then
      local before, after = split_attribution(b)
      blocks[#blocks + 1] = pandoc.Para(before)
      if after then blocks[#blocks + 1] = make_footer(after) end
    else
      blocks[#blocks + 1] = b
    end
  end
  return pandoc.BlockQuote(blocks)
end
