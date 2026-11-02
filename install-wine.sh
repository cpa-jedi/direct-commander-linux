#!/usr/bin/env bash
#
# Установка Яндекс Директ Коммандера на Linux через обычный Wine.
#
#  1. Отключает в префиксе заглушку PowerShell. Без этого официальный установщик
#     и встроенный апдейтер зацикливаются на окне «Не удалось закрыть
#     Direct Commander»: Wine bug 59670, https://bugs.winehq.org/show_bug.cgi?id=59670
#  2. Запускает официальный установщик в тихом режиме.
#
# Ярлык в меню и на рабочем столе делает сам Wine. Обновления программа ставит сама.
#
# Использование:
#   ./install-wine.sh                     возьмёт самый свежий установщик из загрузок
#   ./install-wine.sh /путь/к/файлу.exe
#
# Свой префикс (по умолчанию ~/.wine-dc):
#   WINE_PREFIX=~/.wine-commander ./install-wine.sh

set -euo pipefail

export WINEPREFIX="${WINE_PREFIX:-$HOME/.wine-dc}"
# Wine называет папку пользователя в префиксе по логину; $USER бывает не задан
WIN_HOME="$WINEPREFIX/drive_c/users/${USER:-$(id -un)}"
TARGET="$WIN_HOME/AppData/Local/Programs/Direct Commander"

die() { printf '\nОшибка: %s\n' "$*" >&2; exit 1; }
step() { printf '\n==> %s\n' "$*"; }

# --- проверки ----------------------------------------------------------------

command -v wine >/dev/null 2>&1 || die "не найден wine.
Нужна стоковая сборка от WineHQ: https://gitlab.winehq.org/wine/wine/-/wikis/Download"

# установщик не должен застать программу запущенной
if pgrep -f "Direct Commander.exe" >/dev/null 2>&1; then
  die "Директ Коммандер запущен. Закройте его и повторите."
fi

# --- установщик --------------------------------------------------------------

INSTALLER="${1:-}"
if [ -z "$INSTALLER" ]; then
  # xdg-user-dir знает локализованное имя папки («Загрузки» и т.п.),
  # а если папка не настроена, возвращает $HOME
  DL_DIR="$(xdg-user-dir DOWNLOAD 2>/dev/null || true)"
  if [ -z "$DL_DIR" ] || [ "$DL_DIR" = "$HOME" ]; then
    DL_DIR="$HOME/Downloads"
  fi
  INSTALLER="$(ls -t "$DL_DIR"/*[Cc]ommander*.exe 2>/dev/null | head -1 || true)"
  [ -n "$INSTALLER" ] || die "установщик не найден в $DL_DIR.
Скачайте его с https://yandex.com/project/commander/new
или укажите путь явно: ./install-wine.sh /путь/к/файлу.exe"
  echo "Установщик: $INSTALLER"
fi
[ -f "$INSTALLER" ] || die "файл не найден: $INSTALLER"

# --- префикс -----------------------------------------------------------------

if [ ! -d "$WINEPREFIX/drive_c" ]; then
  step "Создаю префикс $WINEPREFIX"
  # mscoree и mshtml отключены, чтобы Wine не предлагал поставить Mono и Gecko:
  # Коммандеру они не нужны
  WINEDLLOVERRIDES="mscoree=d;mshtml=d" wineboot -u >/dev/null 2>&1 || true
  [ -d "$WINEPREFIX/drive_c" ] || die "не удалось создать префикс $WINEPREFIX"
fi

step "Отключаю заглушку PowerShell (Wine bug 59670)"
wine reg add 'HKCU\Software\Wine\DllOverrides' /v powershell.exe /d '' /f >/dev/null 2>&1 \
  || die "не удалось записать настройку в реестр префикса"

# --- установка ---------------------------------------------------------------

step "Запускаю официальный установщик, окон не будет"
wine "$INSTALLER" /S >/dev/null 2>&1 || true
# ждём, пока закончит и установщик, и Wine, который делает ярлыки
wineserver -w

[ -f "$TARGET/Direct Commander.exe" ] || die "приложение не установилось.
Проверьте, что Wine стоковый, а не игровая сборка (soda, Proton)."

# виндовый ярлык от установщика; линуксовый Wine сделал рядом
rm -f "$WIN_HOME/Desktop/Direct Commander.lnk"

printf '\nГотово. Ярлык «Direct Commander» в меню и на рабочем столе.\n'
printf 'Данные: %s\n' "$WIN_HOME/AppData/Roaming/direct-commander"
