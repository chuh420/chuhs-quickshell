[english](readme.md) | [русский](readme.ru.md)

# still / material

тёплый gruvbox material: графит, кремовый текст, оливковые и янтарные акценты.

оболочка: `~/.config/quickshell/material`. палитра: `theme.qml`.
hyprland: `~/.config/hypr/rice.lua`. фон: `~/.config/rice/wallpaper.svg` и png.
автозапуск: `~/.config/rice/start`. команды интерфейса: `~/.local/bin/chuhshell`.

- super + d - приложения; поиск, стрелки, enter, escape.
- super + space - центр управления.
- super + n - уведомления.
- super + c - история буфера обмена.
- super + ctrl + l - блокировка.
- print - выбрать область и открыть satty.
- ctrl + print - весь экран в файл и буфер обмена.
- нажатие на часы - календарь.
- нажатие на номер рабочего стола - переключение.
- колесо над значком звука - громкость; правая кнопка - mute.
- правая кнопка на проценте громкости - pavucontrol.
- правая кнопка на on/off bluetooth - bluetoothctl в терминале.
- стрелка у сети - iwctl в терминале.

quickshell подхватывает изменения qml автоматически. изменения hyprland применяются через `hyprctl reload`.
gtk и qt приложения могут потребовать повторного запуска для применения темы.

исходные конфиги сохранены в `~/.local/state/rice/backup-*`; путь к последнему - в `last-backup`.
для восстановления остановить quickshell (`qs -c material kill`), вернуть нужные каталоги из резервной копии и выполнить `hyprctl reload`.

добавлены bluez, pipewire-audio и pipewire-pulse: в исходной системе отсутствовали bluetooth daemon и звуковые плагины pipewire. включены bluetooth и пользовательский pipewire-pulse.

## wallpapers

super + b opens the quickshell wallpaper gallery. the control center also has a wallpaper button. click a preview to apply it; use arrow keys and enter for keyboard selection. escape closes the gallery.

images are read from `~/pictures/wallpapers`. reopen the gallery or click refresh after adding images. png, jpeg, webp, avif and bmp are supported.

the choice is saved in `~/.local/state/rice/wallpaper.json` and restored on login. hyprlock uses the same selected image. image paths are passed as separate process arguments, and cached symlinks keep hyprpaper configuration safe for filenames containing spaces or commas.

## keyboard layout

the bar shows en/ru for the main keyboard. click the indicator to switch layouts, or use the existing alt + shift shortcut. changes are handled through hyprland events and show a short system notification. consecutive layout notifications replace one another and are marked transient.
