// Test Bar Example with working CPU Usage, Memory and Clock

import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland // Hyprland IPC access
import QtQuick
import QtQuick.Layouts // For RowLayout
import Quickshell.Io

PanelWindow {
    id: root
    color: "transparent"
    anchors.top: true
    anchors.left: true
    anchors.right: true
    implicitHeight: 28 // 28px tall bar
    Rectangle {
        anchors.fill: parent
        radius: 20
        color: colBg
    }

    // Theme - define once, use everywhere
    property color colBg: "#1a1b26"
    property color colFg: "#a9b1d6"
    property color colMuted: "#444b6a"
    property color colCyan: "#0db9d7"
    property color colBlue: "#7aa2f7"
    property color colYellow: "#e0af68"
    property string fontFamily: "JetBrainsMono Nerd Font"
    property int fontSize: 14

    // System Data
    property int cpuUsage: 0
    property var lastCpuIdle: 0
    property var lastCpuTotal: 0
    property int memUsage: 0

    Process {
        id: cpuProc
        command: ["sh", "-c", "head -1 /proc/stat"]

        // SplitParser calls onRead for each line of output
        stdout: SplitParser {
            onRead: data => {
                var p = data.trim().split(/\s+/)
                var idle = parseInt(p[4]) + parseInt(p[5])
                var total = p.slice(1, 8).reduce((a, b) => a + parseInt(b), 0)
                if (lastCpuTotal > 0) {
                    cpuUsage = Math.round(100 * (1 - (idle - lastCpuIdle) / (total - lastCpuTotal)))
                }
                lastCpuTotal = total
                lastCpuIdle = idle
            }
        }
        Component.onCompleted: running = true
    }

    // Timer to refresh every 2 seconds
    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: {
            cpuProc.running = true
            memProc.running = true
        } 
    }

    Process {
        id: memProc
        command: ["sh", "-c", "free | grep Mem"]
        stdout: SplitParser {
            onRead: data => {
                var parts = data.trim().split(/\s+/)
                var total = parseInt(parts[1]) || 1
                var used = parseInt(parts[2]) || 0
                memUsage = Math.round(100 * used / total)
            }
        }
    }
    Component.onCompleted: running = true

    // Clock - Text with its own Timer
    Text {
        id: clock
        anchors.centerIn: parent
        text: Qt.formatDateTime(new Date(), "ddd, MMM dd HH:mm")
        color: root.colBlue

        Timer {
            interval: 1000
            running: true
            repeat: true
            onTriggered: clock.text = Qt.formatDateTime(new Date(), "ddd, MMM dd HH:mm")
        }
    }
    RowLayout {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        spacing: 8

        // Repeater creates 9 copies, each get an index (0-8)
        Repeater {
            model: 9

            Text {
                property var ws: Hyprland.workspaces.values.find(w => w.id === index + 1)
                property bool isActive: Hyprland.focusedWorkspace?.id === (index + 1)

                text: index + 1
                // cyan = active, blue = has windows, gray = empty
                color: isActive ? root.colCyan : (ws ? root.colBlue : root.colMuted)
                font { pixelSize: 14; bold: true}

                // Click to switch workspace 
                MouseArea {
                    anchors.fill: parent
                    onClicked: Hyprland.dispatch("workspace " + (index + 1))
                }
            }
        }

        Item { Layout.fillWidth: true}

        Text {
            text: "CPU: " + cpuUsage + "%"
            color: root.colYellow
            font { family: root.fontFamily; pixelSize: root.fontSize; bold: true}
        }

        Rectangle { width: 1; height: 16; color: root.colMuted}

        Text {
            text: "Mem: " + memUsage + "%"
            color: root.colCyan
            font { family: root.fontFamily; pixelSize: root.fontSize; bold: true}
        }
    }
}