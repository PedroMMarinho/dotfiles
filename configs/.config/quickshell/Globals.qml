pragma Singleton

import QtQuick
import Quickshell

Singleton {
  // Shared popup context so only one tooltip/popup is active at a time.
  readonly property PopupContext popupContext: PopupContext {}
}
