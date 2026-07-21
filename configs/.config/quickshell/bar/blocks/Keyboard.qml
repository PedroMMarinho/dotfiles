import QtQuick
import Quickshell
import Quickshell.Io
import "../"

BarBlock {
  id: root

  // fcitx5 emits no DBus signal when the input method changes — verified with
  // `dbus-monitor --session "sender='org.fcitx.Fcitx5'"` across a switch — and
  // CurrentInputMethod is a DBus *method*, not a property, so PropertiesChanged
  // does not cover it either. Polling is the only option.
  property string currentIm: ""

  // Ordered IM list for cycling, filled once from the active fcitx5 group.
  property var imList: []

  readonly property var flagFor: ({
    "keyboard-us": "🇺🇸",
    "keyboard-pt": "🇵🇹",
    "pinyin": "🇨🇳"
  })

  // Unknown IMs fall back to their raw name, so adding a layout later degrades
  // visibly instead of rendering an empty block.
  readonly property string label: root.flagFor[root.currentIm] ?? (root.currentIm || "…")

  content: Text {
    anchors.verticalCenter: parent.verticalCenter
    text: root.label
    color: "white"
    // Colour emoji sit high on the line; nudge down so flags align with the
    // neighbouring text blocks.
    font.pointSize: 12
    y: 1
  }

  onClicked: function() {
    if (root.imList.length < 2)
      return;
    const i = root.imList.indexOf(root.currentIm);
    const next = root.imList[(i + 1) % root.imList.length];
    switchProc.command = ["fcitx5-remote", "-s", next];
    switchProc.running = true;
  }

  // Current input method, polled.
  Process {
    id: pollProc
    command: ["fcitx5-remote", "-n"]
    running: true
    stdout: SplitParser {
      onRead: data => root.currentIm = data.trim()
    }
  }

  Timer {
    interval: 100
    running: true
    repeat: true
    onTriggered: pollProc.running = true
  }

  // The IM list for the active group, read once at startup. Emits one name per
  // line. The DBus reply is a flat token stream —
  //   sa(ss) "us" 3 "keyboard-us" "" "keyboard-pt" "" "pinyin" ""
  // — so this drops the leading layout token and keeps every other quoted
  // value, which are the IM names.
  Process {
    id: listProc
    running: true
    command: ["sh", "-c",
      "busctl --user call org.fcitx.Fcitx5 /controller org.fcitx.Fcitx.Controller1 " +
      "InputMethodGroupInfo s \"$(fcitx5-remote -q)\" " +
      "| tr ' ' '\\n' | grep '\"' | tr -d '\"' | tail -n +2 | awk 'NR%2==1'"]
    stdout: SplitParser {
      onRead: data => {
        const name = data.trim();
        if (name.length > 0 && root.imList.indexOf(name) === -1)
          root.imList = [...root.imList, name];
      }
    }
  }

  Process { id: switchProc }
}
