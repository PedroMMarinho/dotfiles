pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Spectrum of the default audio output, sampled by cava.
//
// The bar is instantiated once per monitor, so the cava process is shared here
// rather than owned by a block: consumers call acquire()/release() and the
// process only runs while at least one of them wants data.
Singleton {
  id: root

  // Must match `bars` in bar/blocks/cava.conf.
  readonly property int barCount: 4

  // Latest frame, barCount values normalised to 0..1.
  property var levels: root.silence()

  property int subscribers: 0

  function acquire(): void {
    root.subscribers++;
  }

  function release(): void {
    if (root.subscribers > 0)
      root.subscribers--;
  }

  function silence(): var {
    const frame = [];
    for (let i = 0; i < root.barCount; ++i)
      frame.push(0);
    return frame;
  }

  onSubscribersChanged: {
    if (root.subscribers === 0)
      root.levels = root.silence();
  }

  Process {
    running: root.subscribers > 0
    command: ["cava", "-p", Quickshell.shellPath("bar/blocks/cava.conf")]

    stdout: SplitParser {
      splitMarker: "\n"
      onRead: data => {
        const fields = data.split(";");
        const frame = [];
        for (let i = 0; i < root.barCount; ++i) {
          const value = parseInt(fields[i]);
          frame.push(isNaN(value) ? 0 : Math.min(1, value / 100));
        }
        root.levels = frame;
      }
    }
  }
}
