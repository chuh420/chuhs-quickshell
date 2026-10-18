[english](readme.md) | [русский](readme.ru.md)

# chuh's quickshell

панель и меню для Hyprland на Quickshell в цветах gruvbox material. конфигурация включает центр управления, поиск приложений, календарь, настройки Wi-Fi и Bluetooth, управление звуком и микрофоном, сведения о батарее, галерею обоев и вложенные меню трея. панель показывает рабочие столы, время, ресурсы и раскладку. анимации панелей, кнопок и рабочих столов реализованы в QML.

каталоги `.config` и `.local` повторяют пути относительно домашнего каталога. сохраните существующие файлы перед копированием. замените пути `/home/chuh`, если используете другую учётную запись. конфигурация Hyprland и снимок системы находятся в [dotfiles](https://github.com/chuh420/dotfiles/tree/main/hyprland%20setup).

## установка

нужны Quickshell 0.3.2, Qt 6, Python, python-dbus, python-gobject, ImageMagick, PipeWire, WirePlumber, BlueZ, iwd, hyprpaper, hypridle, hyprlock, swaync, swayosd, rofi, wl-clipboard, cliphist, grim, slurp, satty, kitty и pavucontrol. исходная система использует systemd-resolved для DNS. Pleamar нужен только для ручного запуска старой оболочки.

после копирования пользовательских служб выполните:

```sh
systemctl --user daemon-reload
systemctl --user enable --now rice-shell-assets.path
~/.config/rice/start
```

настройте автозапуск и сочетания клавиш Hyprland по снимку dotfiles. файл `rice.lua` отключает анимации композитора для `material-bar` и `material-overlay`, у которых есть анимации QML. панель резервирует 42 px.

оболочку запускает `rice-quickshell.service`. цель `rice-session.target` обслуживает обои, блокировку по бездействию, уведомления, OSD и историю буфера обмена. сочетания клавиш и обновления приложений обращаются к Quickshell. после правок используйте `systemctl --user restart rice-quickshell.service`; логи: `journalctl --user -u rice-quickshell.service`. если после перезагрузки QML IPC отвечает «not ready to accept queries yet», перезапустите службу.

## управление и состояние

`Super + D` открывает приложения, `Super + Space` центр управления, `Super + B` обои, `Super + N` уведомления, `Super + C` историю буфера. Escape закрывает панель. часы открывают календарь; прокрутка на значке звука меняет громкость, правая кнопка выключает звук. keep awake удерживает запрет автоматической блокировки через Wayland до выключения переключателя или перезапуска оболочки.

поиск поддерживает Unicode в названиях и описаниях. `Ctrl + H` скрывает выбранное приложение, `Ctrl + Shift + H` показывает скрытые. терминальные приложения запускаются через kitty с аргументами и рабочим каталогом из desktop-файла. список скрытых приложений создаётся в `~/.local/state/quickshell/material` и не входит в репозиторий.

обои добавляются в `~/Pictures/Wallpapers`. галерея создаёт превью видимых строк, отменяет ненужные преобразования и хранит кэш в `~/.cache/quickshell/material`. выбор картинки обновляет hyprpaper и hyprlock. состояние обоев, кэши и история буфера остаются на машине.

команды панелей и поведение помощников описаны в [справке](.config/rice/README.md). тесты: `python -m unittest discover -s tests -v`. переподключение сети, сопряжение Bluetooth, смена звуковых устройств, несколько мониторов и новый вход в сеанс требуют проверки на оборудовании.

## сохранённый Pleamar

[конфигурация Pleamar](.config/pleamar/shells/material/readme.md), патчи движка и инструменты замеров сохранены. `systemctl --user start rice-pleamar.service` заменяет Quickshell для ручного сеанса; `systemctl --user start rice-quickshell.service` возвращает Quickshell. службы конфликтуют. сочетания клавиш, обновления приложений и следующий вход используют Quickshell. для панелей Pleamar используйте `pleamar-shell NAME`.

исторические замеры Pleamar находятся в [аудите](docs/audit-2026-10-16.md) и [исследовании отрисовки](docs/optimization-2026-10-16.md).
