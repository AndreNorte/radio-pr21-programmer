# Сборка и запуск

[English](BUILD.md) · **Русский**

В репозитории две разные вещи: утилита на Python (работает везде) и приложение для macOS
(его исходники в репозиторий не входят — см. последний раздел).

## 1. Утилита на Python (все платформы)

Нужен Python 3.9 или новее.

```bash
python3 -m venv .venv
source .venv/bin/activate          # Windows: .venv\Scripts\activate
pip install pyserial

python3 scripts/pr21.py read --out radio.img
```

Какой порт:

| Система | Порт | Замечание |
|---|---|---|
| macOS | `/dev/cu.usbserial*`, `/dev/cu.wchusbserial*` | драйвер CH340 встроен в macOS 13+, ставить ничего не нужно |
| Windows | `COM3`, `COM4`, … | драйвер CH340 обычно ставится сам; смотреть «Диспетчер устройств → Порты» |
| Linux | `/dev/ttyUSB0` | добавить пользователя в группу `dialout` и перелогиниться |

Если автопоиск взял не тот порт, укажите явно:

```bash
python3 scripts/pr21.py read --port /dev/ttyUSB0 --out radio.img     # Linux
python3 scripts/pr21.py read --port COM3 --out radio.img             # Windows
```

Сборка не нужна: это один скрипт. Чтобы запускать как команду:

```bash
cp scripts/pr21.py /usr/local/bin/pr21 && chmod +x /usr/local/bin/pr21
```

## 2. Пакет навыка

Навык — это Markdown плюс скрипт. Пересобрать архив для переноса:

```bash
zip -qr radio-pr21-programmer.zip SKILL.md SKILL.ru.md README.md README.ru.md \
    BUILD.md BUILD.ru.md LICENSE references scripts assets examples
```

Установка в каталог навыков агента (`~/.dsh/skills/radio-pr21/` или
`~/.claude/skills/radio-pr21/`) — распаковать архив туда. Либо просто передать модели
`SKILL.md` и папку `references/` вместе с задачей.

## 3. Приложение для macOS

Графическое приложение — отдельный проект на SwiftUI, его исходники **не** в этом
репозитории. Раздел описывает рецепт сборки, чтобы приложение можно было пересобрать,
если исходники у вас есть.

Что нужно:

- macOS 13 или новее;
- Xcode Command Line Tools (`xcode-select --install`) — полный Xcode не обязателен;
- Swift 5.9+ (`swiftc --version`).

Сборка:

```bash
SDK="$(xcrun --show-sdk-path)"
swiftc -O -parse-as-library -sdk "$SDK" -target x86_64-apple-macos13.0 \
  -o "PR-21 Manager.app/Contents/MacOS/PR21Manager" \
  src/core/*.swift src/ui/*.swift src/main.swift
```

Затем собрать бандл (`Info.plist` с `CFBundleIdentifier`, `CFBundleExecutable`,
`CFBundlePackageType=APPL`) и подписать ad hoc:

```bash
codesign --force --deep --sign - "PR-21 Manager.app"
```

Замечания:

- Слой протокола использует POSIX `termios`, поэтому под Windows не собирается;
  путь для Windows — утилита на Python.
- Приложение собрано и проверено на Intel macOS. Сборка под Apple Silicon возможна
  (`-target arm64-apple-macos13.0` или universal), но не тестировалась.

## 4. Если сборка не идёт

| Симптом | Причина и что делать |
|---|---|
| `'main' attribute cannot be used in a module that contains top-level code` | добавить `-parse-as-library` |
| `mapfile: command not found` | в macOS bash 3.2; не использовать возможности bash 4 или поставить новый bash |
| `swiftc: command not found` | установить Xcode Command Line Tools |
| `serial.SerialException: could not open port` | порт занят или нет прав (Linux: группа `dialout`) |
| Рация не отвечает | см. `references/troubleshooting.md` |
