import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "benekuehn.macbook-fans"
  property bool opened: false
  property string profile: "Checking…"
  property string speeds: ""
  property var fanStats: []

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function refreshStatus() {
    if (!status.running) status.running = true
  }
  function refreshFans() {
    if (!fans.running) fans.running = true
  }
  function setProfile(name) {
    if (apply.running) return
    profile = name === "full" ? "Full speed" : (name === "balanced" ? "Balanced" : "Automatic")
    apply.command = ["pkexec", "/usr/local/libexec/omarchy-macbook-fans-profile", name]
    apply.running = true
  }
  function open() { opened = true; refreshStatus(); refreshFans() }
  function close() { opened = false }
  function toggle() { opened ? close() : open() }
  function parseStatus(raw) {
    var detected = String(raw || "").trim()
    if (detected === "full") profile = "Full speed"
    else if (detected === "balanced") profile = "Balanced"
    else if (detected === "automatic") profile = "Automatic"
  }
  function updateFans(raw) {
    var values = String(raw || "").trim().split(/\s+/).filter(function(v) { return v !== "" })
    var next = []
    for (var i = 0; i + 1 < values.length; i += 2) next.push({ rpm: values[i], max: values[i + 1] })
    fanStats = next
    speeds = next.length ? next.map(function(f) { return f.rpm }).join(" / ") + " RPM" : "Fan data unavailable"
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰈐"
    tooltipText: root.profile + (root.speeds ? " · " + root.speeds : "")
    onPressed: function(button) { if (button === Qt.LeftButton) root.toggle() }
  }

  PopupCard {
    id: popup
    anchorItem: root
    bar: root.bar
    owner: root
    open: root.opened
    contentWidth: popup.fittedContentWidth(Style.space(300))
    contentHeight: popup.fittedContentHeight(content.implicitHeight)
    Column {
      id: content
      anchors.fill: parent
      spacing: Style.space(8)
      Text { text: "MacBook fans"; color: Color.foreground; font.family: Style.font.family; font.bold: true }
      Row {
        id: fanReadout
        width: parent.width
        spacing: Style.space(16)
        Repeater {
          model: root.fanStats
          delegate: Column {
            width: (fanReadout.width - fanReadout.spacing * Math.max(0, root.fanStats.length - 1)) / Math.max(1, root.fanStats.length)
            Text { text: modelData.rpm + " RPM"; color: Color.foreground; font.family: Style.font.family; font.pixelSize: Style.font.baseSize }
            Text { text: "max " + modelData.max + " RPM"; color: Qt.darker(Color.foreground, 1.5); font.family: Style.font.family; font.pixelSize: Style.font.baseSize - 2 }
          }
        }
      }
      Text { visible: root.fanStats.length === 0; text: "Fan data unavailable"; color: Qt.darker(Color.foreground, 1.5); font.family: Style.font.family; font.pixelSize: Style.font.baseSize - 2 }
      Item { width: 1; height: Style.space(4) }
      Repeater {
        model: [
          { name: "Automatic", detail: "Apple’s default temperature curve", profile: "default" },
          { name: "Balanced", detail: "Quiet airflow from 35°C", profile: "balanced" },
          { name: "Full speed", detail: "Maximum cooling at maximum noise", profile: "full" }
        ]
        delegate: BorderSurface {
          id: profileButton
          width: content.width; height: Style.space(52); radius: Style.cornerRadius
          readonly property bool selected: root.profile === modelData.name
          color: mouse.pressed ? Style.pressedFillFor(Color.foreground, Color.accent)
            : (mouse.containsMouse ? Style.hoverFillFor(Color.foreground, Color.accent)
            : (selected ? Style.selectedFillFor(Color.foreground, Color.accent) : "transparent"))
          borderSpec: mouse.containsMouse ? Border.controlSpec("hover-cursor", Color.foreground, Color.accent)
            : (selected && Border.controlHasWidth("selected") ? Border.controlSpec("selected", Color.foreground, Color.accent)
            : Border.controlSpec("normal", Color.foreground, Color.accent))
          Row {
            anchors.fill: parent; anchors.margins: Style.spacing.controlPaddingX
            spacing: Style.spacing.controlGap
            Text { anchors.verticalCenter: parent.verticalCenter; text: modelData.profile === "default" ? "󰌪" : (modelData.profile === "balanced" ? "󰊚" : "󰓅"); color: Color.foreground; font.family: Style.font.family; font.pixelSize: Style.font.title }
            Column {
              width: parent.width - children[0].width - parent.spacing
              anchors.verticalCenter: parent.verticalCenter; spacing: Style.spacing.xs
              Text { text: modelData.name; color: Color.foreground; font.family: Style.font.family; font.pixelSize: Style.font.baseSize; font.bold: profileButton.selected }
              Text { text: modelData.detail; color: Qt.darker(Color.foreground, 1.5); font.family: Style.font.family; font.pixelSize: Style.font.baseSize - 1 }
            }
          }
          MouseArea {
            id: mouse
            anchors.fill: parent; hoverEnabled: true; enabled: !apply.running
            cursorShape: Qt.PointingHandCursor
            onClicked: root.setProfile(modelData.profile)
          }
        }
      }
    }
  }

  Process {
    id: status
    command: [Quickshell.env("HOME") + "/.config/omarchy/plugins/benekuehn.macbook-fans/fan-profile", "status"]
    stdout: StdioCollector { id: statusOutput; waitForEnd: true }
    onExited: root.parseStatus(statusOutput.text)
  }
  Process {
    id: fans
    command: ["bash", "-c", "find /sys/devices -type f -path '*/APP0001:00/fan*_input' -print0 2>/dev/null | sort -zV | xargs -0 -r -n1 sh -c 'cat \"$1\" \"${1%_input}_max\"' sh"]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.updateFans(text) }
  }
  Process {
    id: apply
    onExited: function(exitCode) {
      if (exitCode !== 0) root.refreshStatus()
      root.refreshFans()
    }
  }
  Timer { interval: 5000; running: root.opened; repeat: true; onTriggered: root.refreshFans() }
  Component.onCompleted: { root.refreshStatus(); root.refreshFans() }
}
