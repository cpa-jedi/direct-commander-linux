#!/usr/bin/env bash
#
# Установка Яндекс Директ Коммандера на Linux через обычный Wine.
#
# Скрипт не запускает официальный установщик (под Wine он зацикливается),
# а распаковывает из него готовое Electron-приложение и кладёт в префикс.
#
# Использование:
#   ./install-wine.sh                     — сам найдёт свежий установщик в ~/Downloads
#   ./install-wine.sh /путь/к/файлу.exe   — если он лежит в другом месте
#
# Повторный запуск со свежим установщиком работает как обновление:
# файлы приложения заменяются, пользовательские данные не трогаются.
#
# Переменные окружения:
#   WINE_PREFIX=~/.wine-commander      — свой префикс (по умолчанию ~/.wine-dc)
#   APP_ID=direct-commander-wine       — свои имена лаунчера, ярлыка и иконки
#   APP_NAME="Директ Коммандер (wine)" — своё имя пункта в меню
#   FORCE=1                            — переписать чужой лаунчер с тем же именем

set -euo pipefail

WINE_PREFIX="${WINE_PREFIX:-$HOME/.wine-dc}"
APP_ID="${APP_ID:-direct-commander}"
APP_NAME="${APP_NAME:-Директ Коммандер}"
TARGET="$WINE_PREFIX/drive_c/Program Files (x86)/DirectCommander"
LAUNCHER="$HOME/bin/$APP_ID"
DESKTOP="$HOME/.local/share/applications/$APP_ID.desktop"
ICON="$HOME/.local/share/icons/$APP_ID.png"
DOWNLOAD_URL="https://yandex.com/project/commander/new"
FORCE="${FORCE:-0}"

die() { printf '\nОшибка: %s\n' "$*" >&2; exit 1; }
step() { printf '\n==> %s\n' "$*"; }

# --- проверка окружения ------------------------------------------------------

command -v 7z >/dev/null 2>&1 || die "не найден 7z. Установите: sudo apt install -y p7zip-full"
command -v wine >/dev/null 2>&1 || die "не найден wine.
Нужна стоковая сборка от WineHQ, инструкция по установке:
  https://gitlab.winehq.org/wine/wine/-/wikis/Download"

# страховка перед rm -rf: путь обязан быть внутри домашней папки и оканчиваться на DirectCommander
case "$TARGET" in "$HOME"/*) ;; *) die "префикс должен находиться внутри домашней папки, а он здесь:
  $WINE_PREFIX" ;; esac
[ "${TARGET##*/}" = "DirectCommander" ] || die "неожиданный путь установки: $TARGET"

# лаунчер с таким именем уже есть и ведёт в другой префикс: это чужая установка
if [ -f "$LAUNCHER" ] && ! grep -qF "$WINE_PREFIX/" "$LAUNCHER" 2>/dev/null && [ "$FORCE" != "1" ]; then
  die "лаунчер $LAUNCHER уже существует и ведёт в другую установку.
Если это Коммандер, поставленный через Bottles, не трогайте его: задайте свои имена,
и обе установки будут жить рядом.
  APP_ID=direct-commander-wine APP_NAME='Директ Коммандер (wine)' ./install-wine.sh
Если всё-таки хотите переписать существующий лаунчер:
  FORCE=1 ./install-wine.sh"
fi

# приложение не должно быть запущено: иначе файлы заменятся из-под работающего
# процесса, и он зависнет на экране завершения
if command -v pgrep >/dev/null 2>&1 && [ "$FORCE" != "1" ]; then
  RUNNING=""
  for pid in $(pgrep -f "Direct Commander.exe" 2>/dev/null || true); do
    grep -qzxF "WINEPREFIX=$WINE_PREFIX" "/proc/$pid/environ" 2>/dev/null && RUNNING="$RUNNING $pid"
  done
  [ -z "$RUNNING" ] || die "Директ Коммандер сейчас запущен в этом префиксе (PID:$RUNNING).
Закройте программу и повторите, иначе она зависнет на экране завершения работы."
fi

# --- поиск установщика -------------------------------------------------------

INSTALLER="${1:-}"
if [ -z "$INSTALLER" ]; then
  INSTALLER="$(ls -t "$HOME/Downloads/"*[Cc]ommander*.exe "$HOME/Загрузки/"*[Cc]ommander*.exe 2>/dev/null | head -1 || true)"
  [ -n "$INSTALLER" ] || die "установщик не найден в ~/Downloads.
Скачайте его с $DOWNLOAD_URL и положите в ~/Downloads,
либо укажите путь явно:
  ./install-wine.sh /путь/к/файлу.exe"
  echo "Найден установщик: $(basename "$INSTALLER")"
fi
[ -f "$INSTALLER" ] || die "файл не найден: $INSTALLER"

# --- префикс -----------------------------------------------------------------

if [ ! -d "$WINE_PREFIX/drive_c" ]; then
  step "Создаю префикс Wine: $WINE_PREFIX"
  echo "    первый запуск занимает до минуты"
  # mscoree и mshtml отключены, чтобы Wine не предлагал доставить Mono и Gecko:
  # Electron-приложению они не нужны
  WINEPREFIX="$WINE_PREFIX" WINEDLLOVERRIDES="mscoree=d;mshtml=d" \
    wineboot -u >/dev/null 2>&1 || true
  [ -d "$WINE_PREFIX/drive_c" ] || die "не удалось создать префикс: $WINE_PREFIX
Попробуйте вручную:
  WINEPREFIX='$WINE_PREFIX' wineboot -u"
fi

# --- распаковка --------------------------------------------------------------

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

step "Распаковываю установщик"
( cd "$TMP" && 7z x "$INSTALLER" >/dev/null 2>&1 ) \
  || die "не удалось распаковать файл:
  $INSTALLER
Похоже, он повреждён или это не установщик Коммандера. Проверить можно так:
  7z l \"$INSTALLER\""

if [ ! -f "$TMP/\$PLUGINSDIR/app-32.7z" ]; then
  die "внутри установщика нет app-32.7z, вероятно изменился формат сборки.
Внутри обнаружено: $(ls -A "$TMP" 2>/dev/null | tr '\n' ' ')"
fi

7z x "$TMP/\$PLUGINSDIR/app-32.7z" -o"$TMP/app" >/dev/null \
  || die "не удалось распаковать app-32.7z"
[ -f "$TMP/app/Direct Commander.exe" ] \
  || die "в распакованном приложении нет «Direct Commander.exe»"

# --- установка ---------------------------------------------------------------

step "Копирую приложение в префикс"
rm -rf "$TARGET"
mkdir -p "$TARGET"
cp -r "$TMP/app/." "$TARGET/"
[ -f "$TARGET/Direct Commander.exe" ] || die "копирование не удалось, проверьте свободное место"

step "Готовлю иконку"
ICON_LINE=""
if command -v wrestool >/dev/null 2>&1 && command -v icotool >/dev/null 2>&1; then
  mkdir -p "$TMP/ico" "$(dirname "$ICON")"
  wrestool -x -t 14 "$TARGET/Direct Commander.exe" -o "$TMP/ico" >/dev/null 2>&1 || true
  icotool -x -o "$TMP/ico" "$TMP"/ico/*.ico >/dev/null 2>&1 || true
  BIGGEST="$(ls -S "$TMP"/ico/*.png 2>/dev/null | head -1 || true)"
  if [ -n "$BIGGEST" ]; then
    cp "$BIGGEST" "$ICON"
    ICON_LINE="Icon=$ICON"
    echo "    иконка: $ICON"
  else
    echo "    иконку из exe достать не удалось, ярлык будет без неё"
  fi
else
  echo "    icoutils не установлен, шаг пропущен (sudo apt install -y icoutils)"
fi

step "Создаю скрипт запуска"
mkdir -p "$(dirname "$LAUNCHER")"
cat > "$LAUNCHER" <<EOF
#!/usr/bin/env bash
# Запуск Яндекс Директ Коммандера в префиксе $WINE_PREFIX
#
# Важно: нужна стоковая сборка Wine (winehq-stable и подобные).
# На игровых сборках (soda, Proton и подобных) приложение молча
# падает при создании окна.
#
# Если окно так и не появляется, попробуйте отключить DirectComposition:
#   DC_ARGS=--disable-direct-composition $APP_ID

export WINEPREFIX='$WINE_PREFIX'
cd '$TARGET' || exit 1
exec wine 'Direct Commander.exe' \${DC_ARGS:-}
EOF
chmod +x "$LAUNCHER"

step "Создаю ярлык в меню"
mkdir -p "$(dirname "$DESKTOP")"
{
  echo "[Desktop Entry]"
  echo "Type=Application"
  echo "Name=$APP_NAME"
  echo "Comment=Яндекс Директ Коммандер через Wine"
  echo "Exec=$LAUNCHER"
  [ -n "$ICON_LINE" ] && echo "$ICON_LINE"
  echo "Terminal=false"
  echo "Categories=Office;Network;"
} > "$DESKTOP"

command -v update-desktop-database >/dev/null 2>&1 \
  && update-desktop-database "$(dirname "$DESKTOP")" >/dev/null 2>&1 || true

printf '\nГотово.\n\n'
printf 'Запуск:            %s\n' "$LAUNCHER"
printf 'Или из меню:       «%s»\n' "$APP_NAME"
printf 'Файлы приложения:  %s\n' "$TARGET"
printf 'Данные и логи:     %s\n' "$WINE_PREFIX/drive_c/users/$USER/AppData/Roaming/direct-commander"
printf '\nЕсли %s нет в PATH, добавьте в ~/.bashrc:\n    export PATH="$HOME/bin:$PATH"\n' "$HOME/bin"
printf '\nЕсли это было обновление и Коммандер был открыт, закройте и запустите его заново.\n'
