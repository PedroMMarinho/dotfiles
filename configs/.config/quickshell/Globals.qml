pragma Singleton

import QtQuick
import Quickshell

Singleton {
  // Shared popup context so only one tooltip/popup is active at a time.
  readonly property PopupContext popupContext: PopupContext {}

  // Number of BlockPopups currently open. The bar escalates its layershell
  // keyboard focus while this is non-zero — a popup with a text field cannot
  // receive keys otherwise. Maintained by BlockPopup.qml.
  property int openPopups: 0
  readonly property bool anyPopupOpen: openPopups > 0
}
