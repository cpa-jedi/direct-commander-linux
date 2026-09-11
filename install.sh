#!/usr/bin/env bash
#
# Установка Яндекс Директ Коммандера на Linux через Bottles.
#
# Скрипт не запускает официальный установщик (под Wine он зацикливается),
# а распаковывает из него готовое Electron-приложение и кладёт в бутылку.
#
# Использование:
#   ./install.sh                     — сам найдёт свежий установщик в ~/Downloads
#   ./install.sh /путь/к/файлу.exe   — если он лежит в другом месте
#
# Повторный запуск со свежим установщиком работает как обновление:
# файлы приложения заменяются, пользовательские данные не трогаются.
#
# Имя бутылки по умолчанию — Direct. Своё можно задать переменной:
#   BOTTLE_NAME=МоёИмя ./install.sh

set -euo pipefail

BOTTLE_NAME="${BOTTLE_NAME:-Direct}"
BOTTLE="$HOME/.var/app/com.usebottles.bottles/data/bottles/bottles/$BOTTLE_NAME"
TARGET="$BOTTLE/drive_c/Program Files (x86)/DirectCommander"
LAUNCHER="$HOME/bin/direct-commander"
DESKTOP="$HOME/.local/share/applications/direct-commander.desktop"
ICON="$HOME/.local/share/icons/direct-commander.png"
DOWNLOAD_URL="https://yandex.com/project/commander/new"

die() { printf '\nОшибка: %s\n' "$*" >&2; exit 1; }
step() { printf '\n==> %s\n' "$*"; }

# --- проверка окружения ------------------------------------------------------

command -v 7z >/dev/null 2>&1 || die "не найден 7z. Установите: sudo apt install -y p7zip-full"
command -v flatpak >/dev/null 2>&1 || die "не найден flatpak"
flatpak info com.usebottles.bottles >/dev/null 2>&1 \
  || die "Bottles не установлен: flatpak install flathub com.usebottles.bottles"
[ -d "$BOTTLE" ] || die "бутылка «$BOTTLE_NAME» не найдена по пути:
  $BOTTLE
Создайте её в Bottles (тип «Приложение»), либо укажите своё имя:
  BOTTLE_NAME=<имя> ./install.sh"

# страховка перед rm -rf: путь обязан быть внутри домашней папки и оканчиваться на DirectCommander
case "$TARGET" in "$HOME"/*) ;; *) die "неожиданный путь установки: $TARGET" ;; esac
[ "${TARGET##*/}" = "DirectCommander" ] || die "неожиданный путь установки: $TARGET"

# --- поиск установщика -------------------------------------------------------

INSTALLER="${1:-}"
if [ -z "$INSTALLER" ]; then
  INSTALLER="$(ls -t "$HOME/Downloads/"*[Cc]ommander*.exe "$HOME/Загрузки/"*[Cc]ommander*.exe 2>/dev/null | head -1 || true)"
  [ -n "$INSTALLER" ] || die "установщик не найден в ~/Downloads.
Скачайте его с $DOWNLOAD_URL и положите в ~/Downloads,
либо укажите путь явно:
  ./install.sh /путь/к/файлу.exe"
  echo "Найден установщик: $(basename "$INSTALLER")"
fi
[ -f "$INSTALLER" ] || die "файл не найден: $INSTALLER"

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

step "Копирую приложение в бутылку «$BOTTLE_NAME»"
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
# Запуск Яндекс Директ Коммандера в бутылке «$BOTTLE_NAME».
#
# Важно: используется /app/bin/wine — системная сборка Wine из состава Bottles.
# На игровых сборках (soda и подобных) приложение молча падает при создании окна.
#
# Если окно так и не появляется, попробуйте отключить DirectComposition:
#   DC_ARGS=--disable-direct-composition direct-commander

exec flatpak run --command=bash com.usebottles.bottles -c "
export WINEPREFIX='$BOTTLE'
export DXVK_LOG_LEVEL=none
cd '$TARGET' || exit 1
exec /app/bin/wine 'Direct Commander.exe' \${DC_ARGS:-}
"
EOF
chmod +x "$LAUNCHER"

step "Создаю ярлык в меню"
mkdir -p "$(dirname "$DESKTOP")"
{
  echo "[Desktop Entry]"
  echo "Type=Application"
  echo "Name=Директ Коммандер"
  echo "Comment=Яндекс Директ Коммандер через Wine/Bottles"
  echo "Exec=$LAUNCHER"
  [ -n "$ICON_LINE" ] && echo "$ICON_LINE"
  echo "Terminal=false"
  echo "Categories=Office;Network;"
} > "$DESKTOP"

printf '\nГотово.\n\n'
printf 'Запуск:            %s\n' "$LAUNCHER"
printf 'Или из меню:       «Директ Коммандер»\n'
printf 'Файлы приложения:  %s\n' "$TARGET"
printf 'Данные и логи:     %s\n' "$BOTTLE/drive_c/users/<логин>/AppData/Roaming/direct-commander"
printf '\nЕсли %s нет в PATH, добавьте в ~/.bashrc:\n    export PATH="$HOME/bin:$PATH"\n' "$HOME/bin"
printf '\nЕсли это было обновление и Коммандер был открыт — закройте и запустите его заново.\n'
