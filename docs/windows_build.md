# Windows-сборка

Проект экспортируется в один `CiscoGame.exe` со встроенным PCK и пользовательской иконкой.

## Что уже настроено

- `export_presets.cfg` содержит пресет `Windows Desktop`.
- Архитектура — `x86_64`, PCK встроен в EXE.
- Иконка EXE — `assets/branding/cisco_game.ico`.
- Иконка проекта — `assets/branding/cisco_game_icon.png`.
- Метаданные EXE: `Cisco Game`, версия `1.0.0`.
- Подпись кода отключена, чтобы сборка работала без сертификата.

## Иконки

Исходник лежит в `assets/branding/cisco_game_icon_source.png`. После его замены
перегенерируйте PNG и ICO:

```powershell
python .\tools\generate_windows_branding.py
```

## Сборка

Нужен Godot 4.7.2 с установленными export templates для Windows.

```powershell
$env:GODOT_BIN = "C:\path\to\godot.exe"
.\tools\build_windows.ps1
```

Если Godot доступен как `godot` в `PATH`, параметр можно не задавать:

```powershell
.\tools\build_windows.ps1
```

Готовый файл появится в:

```text
build/windows/CiscoGame.exe
```

Каталог `build/` не попадает в git — это локальный результат сборки.

## Ручная команда

```powershell
godot --headless --path . --export-release "Windows Desktop" build/windows/CiscoGame.exe
```

## Проверка

```powershell
godot --headless --path . res://tests/windows_export_config_test.tscn
```

Тест проверяет пресет, иконки, версию и параметры встраивания PCK.
