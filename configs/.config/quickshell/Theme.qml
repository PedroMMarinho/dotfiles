pragma Singleton

import QtQuick
import Quickshell

Singleton {
  property Item get: black_flat

  Item {
    id: windowsXP

    property string barBgColor: "#235EDC"
    property string buttonBorderColor: "#99000000"
    property bool buttonBorderShadow: false
    property bool onTop: false
    property string iconColor: "green"
    property string iconPressedColor: "green"
    // Wlogout power menu
    property string wlogoutButtonBg: "#33FFFFFF"
    property string wlogoutButtonBgHover: "#66FFFFFF"
    property string wlogoutBorderColor: "#55FFFFFF"
    property string wlogoutSelectedBorder: "#FFD54F"
    property string wlogoutIconColor: "#FFFFFF"
    property string wlogoutIconSelected: "#FFD54F"
    property string wlogoutLabelColor: "#FFFFFF"
    property Gradient barGradient: black_flat.barGradient
    property Gradient buttonInactiveGradientV: Gradient {
      GradientStop { position: 0.0; color: "#55FFFFFF" }
      GradientStop { position: 0.3; color: "#22FFFFFF" }
    }
    property Gradient buttonInactiveGradientH: Gradient {
      orientation: Gradient.Horizontal
      GradientStop { position: 0.0; color: "#55FFFFFF" }
      GradientStop { position: 0.1; color: "#00000000" }
    }
    property Gradient buttonActiveGradient: Gradient {
      GradientStop { position: 0.0; color: "#99000000" }
      GradientStop { position: 0.3; color: "#55000000" }
      GradientStop { position: 1.0; color: "#55000000" }
    }
  }

  Item {
    id: black_flat

    property string barBgColor: "#cc000000"
    property string buttonBorderColor: "#01000000" // Making this transparent breaks things
    property bool buttonBorderShadow: false
    property bool onTop: true
    property string iconColor: "blue"
    property string iconPressedColor: "dark_blue"
    // Wlogout power menu
    property string wlogoutButtonBg: "#22FFFFFF"
    property string wlogoutButtonBgHover: "#33FF55FF"
    property string wlogoutBorderColor: "#33FFFFFF"
    property string wlogoutSelectedBorder: "#FF55FF"
    property string wlogoutIconColor: "#DDFFFFFF"
    property string wlogoutIconSelected: "#FF55FF"
    property string wlogoutLabelColor: "#DDFFFFFF"
    property Gradient barGradient: Gradient {
      GradientStop { position: 0.0; color: "transparent" }
    }
    property Gradient buttonInactiveGradientV: Gradient {
      GradientStop { position: 0.0; color: "transparent" }
    }
    property Gradient buttonInactiveGradientH: Gradient {
      orientation: Gradient.Horizontal
      GradientStop { position: 0.0; color: "transparent" }
    }
    property Gradient buttonActiveGradient: Gradient {
      GradientStop { position: 0.92; color: "#FF000000" }
      GradientStop { position: 0.93; color: "#FFFFFFFF" }
      GradientStop { position: 1.0; color: "#FFFFFFFF" }
    }
  }
}
