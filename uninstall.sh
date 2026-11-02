#!/usr/bin/env bash
#
# Удаление Директ Коммандера, установленного через install-wine.sh.
# Пользовательские данные (кампании, настройки, авторизация) и сам префикс
# остаются, пути к ним печатаются в конце.
#
# Использование:
#   ./uninstall.sh
#   WINE_PREFIX=~/.wine-commander ./uninstall.sh   если префикс свой

set -euo pipefail

export WINEPREFIX="${WINE_PREFIX:-$HOME/.wine-dc}"
WIN_HOME="$WINEPREFIX/drive_c/users/${USER:-$(id -un)}"
TARGET="$WIN_HOME/AppData/Local/Programs/Direct Commander"

die() { printf '\nОшибка: %s\n' "$*" >&2; exit 1; }

# --- проверки ----------------------------------------------------------------

[ -d "$WINEPREFIX/drive_c" ] || die "префикс не найден: $WINEPREFIX"
case "$WINEPREFIX" in "$HOME"/?*) ;; *) die "неожиданный путь префикса: $WINEPREFIX" ;; esac

# иначе после удаления файлов окно зависнет на экране завершения
if pgrep -f "Direct Commander.exe" >/dev/null 2>&1; then
  die "Директ Коммандер запущен. Закройте его и повторите."
fi

# --- удаление ----------------------------------------------------------------

# штатный деинсталлятор убирает программу и запись в реестре префикса
if [ -f "$TARGET/Uninstall Direct Commander.exe" ]; then
  wine "$TARGET/Uninstall Direct Commander.exe" /currentuser /S >/dev/null 2>&1 || true
  wineserver -w
fi
rm -rf "$TARGET"

# ярлыки, которые сделал Wine: сам он их не убирает. Только ведущие в этот префикс.
DESKTOP_DIR="$(readlink -f "$WIN_HOME/Desktop" || true)"
for f in "$HOME/.local/share/applications/wine/Programs/Direct Commander.desktop" \
         "$DESKTOP_DIR/Direct Commander.desktop"; do
  [ -f "$f" ] && grep -qF "WINEPREFIX=\"$WINEPREFIX\"" "$f" || continue
  ICON="$(sed -n 's/^Icon=//p' "$f")"
  [ -z "$ICON" ] || rm -f "$HOME/.local/share/icons/hicolor/"*/apps/"$ICON.png"
  rm -f "$f"
done

printf '\nКоммандер удалён.\n'
printf 'Данные остались: %s\n' "$WIN_HOME/AppData/Roaming/direct-commander"
printf 'Префикс целиком удаляется так: rm -rf "%s"\n' "$WINEPREFIX"
