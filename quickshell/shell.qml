pragma ComponentBehavior: Bound

import QtCore
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: root

    property var niriWorkspaces: ({})
    property var niriAllWorkspaces: []
    property var niriWindows: ({})
    property bool niriWorkspaceEmpty: true
    property string niriActiveWindowTitle: ""
    property string niriFocusedWorkspaceId: ""

    Socket {
        id: niriSocket
        path: Quickshell.env("NIRI_SOCKET")
        connected: false

        parser: SplitParser {
            onRead: line => {
                try { root.handleNiriEvent(JSON.parse(line)) }
                catch (e) { console.warn("niri parse err:", e) }
            }
        }

        onConnectedChanged: {
            if (connected) { write('"EventStream"\n'); flush() }
        }
        Component.onCompleted: {
            connected = true
        }
    }

    property var _niriFocusWindowId: null

    function handleNiriEvent(event) {
        const keys = Object.keys(event)
        if (keys.length === 0) return
        const type = keys[0], data = event[type]
        switch (type) {
            case "WorkspacesChanged": handleWSC(data); break
            case "WindowsChanged": handleWinC(data); break
            case "WindowFocusChanged": handleWFocus(data); break
        }
    }

    function handleWSC(data) {
        const m = {}
        for (const ws of data.workspaces)
            m[ws.id] = JSON.parse(JSON.stringify(ws))
        niriWorkspaces = m
        niriAllWorkspaces = Object.values(m).sort((a,b) => a.idx - b.idx)
        const f = niriAllWorkspaces.find(w => w.is_focused)
        if (f) {
            niriFocusedWorkspaceId = f.id
            _niriFocusWindowId = f.active_window_id
        }
        syncActive()
    }

    function handleWinC(data) {
        const m = {}
        for (const w of data.windows)
            m[w.id] = JSON.parse(JSON.stringify(w))
        niriWindows = m
        syncActive()
    }

    function handleWFocus(data) {
        _niriFocusWindowId = data.id
        syncActive()
    }

    function syncActive() {
        niriWorkspaceEmpty = !_niriFocusWindowId || _niriFocusWindowId === 0
        const win = niriWindows[_niriFocusWindowId]
        niriActiveWindowTitle = win ? win.title : ""
    }

    function launchWalker() { Quickshell.execDetached({ command: ["walker"] }) }
    function launchKitty() { Quickshell.execDetached({ command: ["env","WINIT_UNIX_BACKEND=wayland","kitty"] }) }
    function launchFirefox() { Quickshell.execDetached({ command: ["firefox"] }) }
    function launchYoutube() { Quickshell.execDetached({ command: ["gtk-launch","youtube-webapp"] }) }
    function launchCalendar() { Quickshell.execDetached({ command: ["gnome-calendar"] }) }
    function launchBluetooth() { Quickshell.execDetached({ command: ["blueman-manager"] }) }
    function launchNetwork() { Quickshell.execDetached({ command: ["gnome-control-center","network"] }) }
    function launchAudio() { Quickshell.execDetached({ command: ["pavucontrol"] }) }

    Process {
        id: initFetch
        command: ["niri", "msg", "-j", "workspaces"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text)
                    if (d.workspaces) root.handleWSC(d)
                } catch (e) { console.warn("fetch err:", e) }
            }
        }
    }

    Process {
        id: initFetchWindows
        command: ["niri", "msg", "-j", "windows"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text)
                    if (d.windows) root.handleWinC(d)
                } catch (e) { console.warn("fetch wins err:", e) }
            }
        }
    }

    TopBar {
        activeWindowTitle: root.niriActiveWindowTitle
        onOpenCalendar: root.launchCalendar()
        onOpenBluetooth: root.launchBluetooth()
        onOpenNetwork: root.launchNetwork()
        onOpenAudio: root.launchAudio()
    }

    BottomDock {
        workspaceEmpty: root.niriWorkspaceEmpty
        onSummonWalker: root.launchWalker()
        onSummonKitty: root.launchKitty()
        onSummonFirefox: root.launchFirefox()
        onSummonYoutube: root.launchYoutube()
    }
}
