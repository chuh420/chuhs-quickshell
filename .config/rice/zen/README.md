# Zen · Gruvbox Material

The browser uses the same graphite, cream, olive and amber palette as the desktop.

- `material-chrome.css`: browser frame, sidebar, tabs, address bar, search popup, menus and find bar.
- `material-content.css`: new tab and internal settings pages.
- Both profiles registered in `~/.config/zen/profiles.ini` import these shared styles from their `chrome/userChrome.css` and `chrome/userContent.css`.
- Profile `user.js` enables stylesheets, dark mode, the olive accent and English UI.

Restart Zen after editing the CSS. Selectors were checked against the installed Zen 1.23b sources and the running browser. Browser updates may require selector adjustments.

The backup path is stored in `~/.local/state/rice/zen-last-backup`. It includes existing chrome files and preferences. To undo, close Zen, restore those files, and remove the newly added imports and preferences where no previous file existed.
