#!/usr/bin/env bash
#
# Удаление Директ Коммандера, установленного через install.sh.
# Пользовательские данные (кампании, настройки, логины) НЕ удаляются —
# путь к ним печатается в конце, удаляйте вручную, если нужно.

set -euo pipefail

BOTTLE_NAME="${BOTTLE_NAME:-Direct}"
BOTTLE="$HOME/.var/app/com.usebottles.bottles/data/bottles/bottles/$BOTTLE_NAME"
TARGET="$BOTTLE/drive_c/Program Files (x86)/DirectCommander"
LAUNCHER="$HOME/bin/direct-commander"
DESKTOP="$HOME/.local/share/applications/direct-commander.desktop"
ICON="$HOME/.local/share/icons/direct-commander.png"

# страховка перед rm -rf: путь обязан быть внутри домашней папки и оканчиваться на DirectCommander
case "$TARGET" in "$HOME"/*) ;; *) echo "Неожиданный путь: $TARGET" >&2; exit 1 ;; esac
[ "${TARGET##*/}" = "DirectCommander" ] || { echo "Неожиданный путь: $TARGET" >&2; exit 1; }

rm -rf "$TARGET"
rm -f "$LAUNCHER" "$DESKTOP" "$ICON"

printf 'Приложение и ярлык удалены.\n\n'
printf 'Пользовательские данные остались здесь:\n  %s\n' \
  "$BOTTLE/drive_c/users/*/AppData/Roaming/direct-commander"
printf '\nСама бутылка «%s» тоже осталась — удалить её можно из интерфейса Bottles.\n' "$BOTTLE_NAME"
