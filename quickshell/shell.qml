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
    property var niriOutputEmpty: ({})
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
    property bool _pendingDockLaunch: false
    property var _previousWindows: ({})

    function handleNiriEvent(event) {
        const keys = Object.keys(event)
        if (keys.length === 0) return
        const type = keys[0], data = event[type]
        switch (type) {
            case "WorkspacesChanged": handleWSC(data); break
            case "WorkspaceActiveWindowChanged": handleWSAWC(data); break
            case "WorkspaceActivated": handleWSA(data); break
            case "WindowsChanged": handleWinC(data); break
            case "WindowFocusChanged": handleWFocus(data); break
        }
    }

    function handleWSC(data) {
        const m = {}
        const empty = {}
        for (const ws of data.workspaces) {
            m[ws.id] = JSON.parse(JSON.stringify(ws))
            if (ws.output != null)
                empty[ws.output] = !ws.active_window_id || ws.active_window_id === 0
        }
        niriWorkspaces = m
        niriOutputEmpty = empty
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
        if (root._pendingDockLaunch) {
            for (const id of Object.keys(m)) {
                if (!(id in root._previousWindows)) {
                    const win = m[id]
                    const wsId = win.workspace_id
                    if (wsId !== null && wsId !== undefined && Number(wsId) !== Number(niriFocusedWorkspaceId)) {
                        const wsEntry = niriAllWorkspaces.find(w => Number(w.id) === wsId)
                        const target = wsEntry && wsEntry.name ? wsEntry.name : String(wsId)
                        Quickshell.execDetached({ command: ["niri","msg","action","focus-workspace", target] })
                    }
                    break
                }
            }
            root._pendingDockLaunch = false
        }
        niriWindows = m
        root._previousWindows = {}
        for (const id of Object.keys(m))
            root._previousWindows[id] = true
        const empty = {}
        for (const ws of niriAllWorkspaces) {
            if (ws.output != null) {
                const hasWindow = Object.values(m).some(w => Number(w.workspace_id) === Number(ws.id))
                empty[ws.output] = !hasWindow
            }
        }
        niriOutputEmpty = empty
        syncActive()
    }

    function handleWSAWC(data) {
        const ws = niriWorkspaces[data.workspace_id]
        if (ws && ws.output != null) {
            const empty = {}
            for (const key of Object.keys(niriOutputEmpty))
                empty[key] = niriOutputEmpty[key]
            empty[ws.output] = !data.active_window_id || data.active_window_id === 0
            niriOutputEmpty = empty
        }
    }

    function handleWSA(data) {
        const ws = niriWorkspaces[data.id]
        if (ws && ws.output != null) {
            const empty = {}
            for (const key of Object.keys(niriOutputEmpty))
                empty[key] = niriOutputEmpty[key]
            empty[ws.output] = !ws.active_window_id || ws.active_window_id === 0
            niriOutputEmpty = empty
        }
        if (data.focused) {
            niriFocusedWorkspaceId = String(data.id)
            _niriFocusWindowId = ws ? ws.active_window_id : null
            syncActive()
        }
    }

    function handleWFocus(data) {
        _niriFocusWindowId = data.id
        syncActive()
    }

    function syncActive() {
        const win = niriWindows[_niriFocusWindowId]
        niriActiveWindowTitle = win ? win.title : ""
    }

    property var cpuUsage: []
    property real cpuTotal: 0
    property var _prevCpu: null

    function parseCpuStats(text) {
        const lines = text.trim().split('\n')
        const current = {}
        for (const line of lines) {
            if (!line.startsWith("cpu")) break
            const parts = line.trim().split(/\s+/)
            current[parts[0]] = parts.slice(1).map(Number)
        }
        if (!root._prevCpu) { root._prevCpu = current; return }
        const usage = {}
        for (const key of Object.keys(current)) {
            const prev = root._prevCpu[key]
            const cur = current[key]
            if (!prev) continue
            const totalDelta = cur.reduce((a,b) => a+b, 0) - prev.reduce((a,b) => a+b, 0)
            const idleDelta = (cur[3] || 0) - (prev[3] || 0)
            usage[key] = totalDelta > 0 ? Math.min(100, Math.max(0, (1 - idleDelta / totalDelta) * 100)) : 0
        }
        root._prevCpu = current
        root.cpuTotal = Math.round((usage["cpu"] || 0) * 10) / 10
        const cores = Object.keys(usage).filter(k => k !== "cpu").sort()
        root.cpuUsage = cores.map(k => Math.round((usage[k] || 0) * 10) / 10)
    }

    Process {
        id: cpuReader
        command: ["cat", "/proc/stat"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: root.parseCpuStats(text)
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: cpuReader.running = true
    }

    function launchWalker() { Quickshell.execDetached({ command: ["walker"] }) }
    function launchKitty() { root._pendingDockLaunch = true; Quickshell.execDetached({ command: ["env","WINIT_UNIX_BACKEND=wayland","kitty"] }) }
    function launchFirefox() { root._pendingDockLaunch = true; Quickshell.execDetached({ command: ["firefox"] }) }
    function launchYoutube() { root._pendingDockLaunch = true; Quickshell.execDetached({ command: ["gtk-launch","youtube-webapp"] }) }
    function launchCalendar() { Quickshell.execDetached({ command: ["gnome-calendar"] }) }
    function launchBluetooth() { Quickshell.execDetached({ command: ["kitty","-e","bluetui"] }) }
    function launchNetwork() { Quickshell.execDetached({ command: ["gnome-control-center","network"] }) }
    function launchAudio() { Quickshell.execDetached({ command: ["kitty","-e","wiremix"] }) }
    function launchBtop() { Quickshell.execDetached({ command: ["kitty","-e","btop"] }) }


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

    Variants {
        model: Quickshell.screens.filter(s => ["DP-1", "HDMI-A-1", "DP-2"].includes(s.name))
        TopBar {
            screen: modelData
            workspaceEmpty: root.niriOutputEmpty[modelData.name] ?? true
            activeWindowTitle: root.niriActiveWindowTitle
            cpuUsage: root.cpuUsage
            cpuTotal: root.cpuTotal
            onOpenCalendar: root.launchCalendar()
            onOpenBluetooth: root.launchBluetooth()
            onOpenNetwork: root.launchNetwork()
            onOpenAudio: root.launchAudio()
            onOpenBtop: root.launchBtop()
        }
    }

    Variants {
        model: Quickshell.screens.filter(s => ["DP-1", "HDMI-A-1", "DP-2"].includes(s.name))
        BottomDock {
            screen: modelData
            workspaceEmpty: root.niriOutputEmpty[modelData.name] ?? true
            onSummonWalker: root.launchWalker()
            onSummonKitty: root.launchKitty()
            onSummonFirefox: root.launchFirefox()
            onSummonYoutube: root.launchYoutube()
        }
    }
}
