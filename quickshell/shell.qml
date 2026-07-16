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
    property bool _wsRefreshQueued: false
    property bool _winRefreshQueued: false

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: {
            if (!root._wsRefreshQueued) root.wsRefresher.running = true
            if (!root._winRefreshQueued) root.winRefresher.running = true
        }
    }

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
            case "WindowOpenedOrChanged": handleWindowOpenedOrChanged(data); break
            case "WindowClosed": handleWindowClosed(data); break
            case "WindowLayoutsChanged": handleWLC(); break
        }
    }

    function handleWSC(data) {
        const m = {}
        const all = []
        for (const ws of data.workspaces) {
            m[ws.id] = JSON.parse(JSON.stringify(ws))
            all.push(m[ws.id])
        }
        all.sort((a, b) => a.idx - b.idx)
        niriWorkspaces = m
        niriAllWorkspaces = all

        const focused = all.find(w => w.is_focused)
        if (focused) {
            niriFocusedWorkspaceId = focused.id
            _niriFocusWindowId = focused.active_window_id
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

        syncActive()
    }

    function handleWSAWC(data) {
        if (winRefresher.running) {
            _winRefreshQueued = true
        } else {
            winRefresher.running = true
        }
    }

    Process {
        id: wsRefresher
        command: ["niri", "msg", "-j", "workspaces"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text)
                    if (d.workspaces) root.handleWSC(d)
                } catch (e) { console.warn("ws refresh err:", e) }
                if (root._wsRefreshQueued) {
                    root._wsRefreshQueued = false
                    root.wsRefresher.running = true
                }
            }
        }
    }

    Process {
        id: winRefresher
        command: ["niri", "msg", "-j", "windows"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text)
                    if (d.windows) root.handleWinC(d)
                } catch (e) { console.warn("win refresh err:", e) }
                if (root._winRefreshQueued) {
                    root._winRefreshQueued = false
                    root.winRefresher.running = true
                }
            }
        }
    }

    function handleWSA(data) {
        if (data.focused) {
            niriFocusedWorkspaceId = String(data.id)
            const ws = niriWorkspaces[data.id]
            if (ws) _niriFocusWindowId = ws.active_window_id
            syncActive()
        }
        if (wsRefresher.running) {
            _wsRefreshQueued = true
        } else {
            wsRefresher.running = true
        }
    }

    function handleWFocus(data) {
        _niriFocusWindowId = data.id
        syncActive()
    }

    function handleWindowOpenedOrChanged(data) {
        const win = JSON.parse(JSON.stringify(data.window))
        const m = JSON.parse(JSON.stringify(niriWindows))
        m[win.id] = win
        niriWindows = m
        syncActive()
    }

    function handleWindowClosed(data) {
        const m = JSON.parse(JSON.stringify(niriWindows))
        delete m[data.id]
        niriWindows = m
        syncActive()
    }

    function handleWLC() {
        if (winRefresher.running) {
            _winRefreshQueued = true
        } else {
            winRefresher.running = true
        }
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
}
