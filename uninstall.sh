#!/usr/bin/env bash
#
# Удаление Директ Коммандера, установленного через install.sh или install-wine.sh.
# Пользовательские данные (кампании, настройки, логины) НЕ удаляются:
# путь к ним печатается в конце, удаляйте вручную, если нужно.
#
# Использование:
#   ./uninstall.sh            — удалить установку через Bottles (по умолчанию)
#   ./uninstall.sh --wine     — удалить установку через обычный Wine
#   ./uninstall.sh --force    — удалять, даже если приложение уже не на месте
#
# Переменные окружения:
#   BOTTLE_NAME=МоёИмя        — имя бутылки, если оно не Direct
#   WINE_PREFIX=~/.wine-dc    — префикс, если он не ~/.wine-dc
#   APP_ID=direct-commander   — имена лаунчера, ярлыка и иконки

set -euo pipefail

MODE="${MODE:-bottles}"
FORCE=0

while [ $# -gt 0 ]; do
  case "$1" in
    --wine)    MODE="wine" ;;
    --bottles) MODE="bottles" ;;
    --force)   FORCE=1 ;;
    *) echo "Неизвестный аргумент: $1 (ожидаются --wine, --bottles, --force)" >&2; exit 1 ;;
  esac
  shift
done

APP_ID="${APP_ID:-direct-commander}"
LAUNCHER="$HOME/bin/$APP_ID"
DESKTOP="$HOME/.local/share/applications/$APP_ID.desktop"
ICON="$HOME/.local/share/icons/$APP_ID.png"

if [ "$MODE" = "wine" ]; then
  WINE_PREFIX="${WINE_PREFIX:-$HOME/.wine-dc}"
  ROOT="$WINE_PREFIX"
  WHAT="префикс $WINE_PREFIX"
  OTHER="через Bottles, для неё запустите ./uninstall.sh без аргументов"
else
  BOTTLE_NAME="${BOTTLE_NAME:-Direct}"
  ROOT="$HOME/.var/app/com.usebottles.bottles/data/bottles/bottles/$BOTTLE_NAME"
  WHAT="бутылка «$BOTTLE_NAME»"
  OTHER="через обычный Wine, для неё запустите ./uninstall.sh --wine"
fi
TARGET="$ROOT/drive_c/Program Files (x86)/DirectCommander"

# страховка перед rm -rf: путь обязан быть внутри домашней папки и оканчиваться на DirectCommander
case "$TARGET" in "$HOME"/*) ;; *) echo "Неожиданный путь: $TARGET" >&2; exit 1 ;; esac
[ "${TARGET##*/}" = "DirectCommander" ] || { echo "Неожиданный путь: $TARGET" >&2; exit 1; }

# --- ничего не удаляем, если это не та установка -----------------------------

if [ ! -d "$TARGET" ] && [ "$FORCE" -eq 0 ]; then
  echo "Приложение не найдено по пути:" >&2
  echo "  $TARGET" >&2
  echo >&2
  echo "Выбран режим: $WHAT." >&2
  echo "Если вы ставили Коммандер $OTHER." >&2
  echo "Если приложение вы уже удалили руками и нужно убрать только ярлык:" >&2
  echo "  ./uninstall.sh --force" >&2
  exit 1
fi

# лаунчер ссылается на свою установку: если он указывает куда-то ещё,
# значит режим и APP_ID не от одной установки, и трогать тут нечего
if [ -f "$LAUNCHER" ] && ! grep -qF "$ROOT/" "$LAUNCHER" 2>/dev/null && [ "$FORCE" -eq 0 ]; then
  echo "Ярлык и установка не совпадают, ничего не удаляю." >&2
  echo >&2
  echo "  $LAUNCHER ссылается не на $ROOT" >&2
  echo >&2
  echo "Похоже, APP_ID и режим взяты от разных установок." >&2
  echo "Запустите с теми же переменными, с какими ставили, например:" >&2
  echo "  APP_ID=$APP_ID WINE_PREFIX=<ваш префикс> ./uninstall.sh --wine" >&2
  exit 1
fi

# приложение не должно быть запущено: иначе после удаления файлов оно зависнет
if command -v pgrep >/dev/null 2>&1 && [ "$FORCE" -eq 0 ]; then
  RUNNING=""
  for pid in $(pgrep -f "Direct Commander.exe" 2>/dev/null || true); do
    grep -qzxF "WINEPREFIX=$ROOT" "/proc/$pid/environ" 2>/dev/null && RUNNING="$RUNNING $pid"
  done
  if [ -n "$RUNNING" ]; then
    echo "Директ Коммандер сейчас запущен в этой установке (PID:$RUNNING)." >&2
    echo "Закройте программу и повторите, иначе окно зависнет на экране завершения." >&2
    echo "Если окно уже не отвечает, прибейте процесс:" >&2
    echo "  kill$RUNNING" >&2
    exit 1
  fi
fi

# --- удаление ----------------------------------------------------------------

rm -rf "$TARGET"
rm -f "$LAUNCHER" "$DESKTOP" "$ICON"

command -v update-desktop-database >/dev/null 2>&1 \
  && update-desktop-database "$(dirname "$DESKTOP")" >/dev/null 2>&1 || true

printf '\nПриложение, ярлык и иконка удалены (%s).\n' "$WHAT"
printf '\nПользовательские данные остались здесь:\n  %s\n' \
  "$ROOT/drive_c/users/$USER/AppData/Roaming/direct-commander"

if [ "$MODE" = "wine" ]; then
  printf '\nСам префикс тоже остался. Если он больше не нужен, удалите его целиком:\n    rm -rf "%s"\n' "$WINE_PREFIX"
else
  printf '\nСама бутылка «%s» тоже осталась, удалить её можно из интерфейса Bottles.\n' "$BOTTLE_NAME"
fi
