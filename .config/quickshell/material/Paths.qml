pragma Singleton
import QtQuick
import Quickshell
Singleton {
    readonly property string home: Quickshell.env("HOME")
    readonly property string rice: home + "/.config/rice"
    readonly property string helpers: Quickshell.shellPath("helpers")
    readonly property string chuhshell: home + "/.local/bin/chuhshell"
    readonly property string wallpaperState: home + "/.local/state/rice/wallpaper.json"
    function helper(name) { return helpers + "/" + name }
    function riceScript(name) { return rice + "/" + name }
}
