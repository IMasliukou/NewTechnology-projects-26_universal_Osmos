#!/usr/bin/env bash
# Синхронизация Cursor-правил из репозитория-базы знаний стандартов
# ModernTechnologies в этот проект (.cursor/rules/).
#
# Модель: база знаний (папка standards/ в отдельном репозитории) — ИСТОЧНИК
# ИСТИНЫ. Стандарты там эволюционируют. Этот скрипт тянет актуальные правила
# (*.mdc) и раскладывает их в .cursor/rules/, чтобы агент соблюдал их здесь.
#
# Настройки берутся из standards.sync.conf (или одноимённых переменных окружения):
#   STANDARDS_REPO  — git-URL базы знаний
#   STANDARDS_REF   — ветка/тег (по умолчанию main)
#   STANDARDS_SRC   — путь к папке с *.mdc внутри базы знаний
#
# Запуск:
#   scripts/sync-standards.sh            # обычная синхронизация
#   STANDARDS_REF=v1.2 scripts/sync-standards.sh   # зафиксировать версию стандартов
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# 1) Загрузка конфигурации. env имеет приоритет над файлом:
#    запоминаем значения из окружения, читаем файл, затем возвращаем env-значения.
_ENV_REPO="${STANDARDS_REPO:-}"
_ENV_REF="${STANDARDS_REF:-}"
_ENV_SRC="${STANDARDS_SRC:-}"
CONF_FILE="${REPO_ROOT}/standards.sync.conf"
if [ -f "$CONF_FILE" ]; then
  # shellcheck disable=SC1090
  set -a; . "$CONF_FILE"; set +a
fi
STANDARDS_REPO="${_ENV_REPO:-${STANDARDS_REPO:-}}"
STANDARDS_REF="${_ENV_REF:-${STANDARDS_REF:-main}}"
STANDARDS_SRC="${_ENV_SRC:-${STANDARDS_SRC:-standards/cursor-rules}}"

RULES_DIR="${REPO_ROOT}/.cursor/rules"
CACHE_DIR="${REPO_ROOT}/.standards-cache"
MANIFEST="${RULES_DIR}/.standards-manifest"

if [ -z "$STANDARDS_REPO" ]; then
  cat >&2 <<EOF
[sync-standards] STANDARDS_REPO не задан.
Укажите git-URL базы знаний в standards.sync.conf (или переменной окружения),
например:
  STANDARDS_REPO="https://github.com/IMasliukou/modtech-standards.git"
Пропускаю синхронизацию (это не ошибка).
EOF
  exit 0
fi

command -v git >/dev/null 2>&1 || { echo "[sync-standards] git не найден" >&2; exit 1; }

# 2) Клонируем/обновляем кэш базы знаний (мелкий клон нужной ветки).
if [ -d "${CACHE_DIR}/.git" ]; then
  echo "[sync-standards] Обновляю базу знаний (${STANDARDS_REF})…"
  git -C "$CACHE_DIR" remote set-url origin "$STANDARDS_REPO"
  git -C "$CACHE_DIR" fetch --depth 1 origin "$STANDARDS_REF"
  git -C "$CACHE_DIR" checkout -q -B "$STANDARDS_REF" FETCH_HEAD
else
  echo "[sync-standards] Клонирую базу знаний: $STANDARDS_REPO (${STANDARDS_REF})…"
  rm -rf "$CACHE_DIR"
  git clone --depth 1 --branch "$STANDARDS_REF" "$STANDARDS_REPO" "$CACHE_DIR"
fi

SRC_DIR="${CACHE_DIR}/${STANDARDS_SRC}"
if [ ! -d "$SRC_DIR" ]; then
  echo "[sync-standards] В базе знаний нет папки '${STANDARDS_SRC}'. Проверьте STANDARDS_SRC." >&2
  exit 1
fi

mkdir -p "$RULES_DIR"

# 3) Удаляем ранее синхронизированные правила, которых больше нет в базе знаний
#    (список ведём в манифесте, чтобы не трогать локальные правила проекта).
if [ -f "$MANIFEST" ]; then
  while IFS= read -r old; do
    [ -n "$old" ] || continue
    if [ ! -f "${SRC_DIR}/${old}" ] && [ -f "${RULES_DIR}/${old}" ]; then
      echo "[sync-standards] Удаляю устаревшее правило: ${old}"
      rm -f "${RULES_DIR}/${old}"
    fi
  done < "$MANIFEST"
fi

# 4) Копируем актуальные правила (*.mdc) и обновляем манифест.
: > "${MANIFEST}.tmp"
count=0
while IFS= read -r -d '' f; do
  rel="${f#"$SRC_DIR"/}"
  dest="${RULES_DIR}/${rel}"
  mkdir -p "$(dirname "$dest")"
  cp "$f" "$dest"
  echo "$rel" >> "${MANIFEST}.tmp"
  count=$((count+1))
done < <(find "$SRC_DIR" -type f -name '*.mdc' -print0 | sort -z)

sort "${MANIFEST}.tmp" > "$MANIFEST" && rm -f "${MANIFEST}.tmp"

synced_ref="$(git -C "$CACHE_DIR" rev-parse --short HEAD 2>/dev/null || echo '?')"
echo "[sync-standards] Готово: синхронизировано правил — ${count} (база знаний @ ${synced_ref})."
echo "[sync-standards] Проверьте изменения в .cursor/rules/ и закоммитьте их."
