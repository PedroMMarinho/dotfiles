pragma Singleton

import QtQuick
import Quickshell

Singleton {
  property Item get: whiteSur_dark

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
    // Frosted panel (power menu container)
    property string wlogoutPanelBg: "#CC12244F"
    property string wlogoutPanelBorder: "#55FFFFFF"
    // Lock screen
    property string lockAccent: "#FFD54F"
    property string lockText: "#FFFFFF"
    property string lockTextDim: "#C8FFFFFF"
    property string lockTextError: "#FFD0D0"
    property string lockGlassTint: "#2EFFFFFF"
    property string lockGlassBorder: "#59FFFFFF"
    property string lockGlassTintError: "#40FF5555"
    property string lockGlassBorderError: "#CCFF5555"
    property string lockAvatarBg: "#33FFFFFF"
    property string lockAvatarBorder: "#66FFFFFF"
    property string lockTrayTint: "#26FFFFFF"
    property string lockTrayBorder: "#3AFFFFFF"
    property string lockGlassText: "#73FFFFFF"
    

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
    // Frosted panel (power menu container)
    property string wlogoutPanelBg: "#CC1A1A1A"
    property string wlogoutPanelBorder: "#33FFFFFF"
    // Lock screen
    property string lockAccent: "#FF55FF"
    property string lockText: "#FFFFFF"
    property string lockTextDim: "#C8FFFFFF"
    property string lockTextError: "#FFD0D0"
    property string lockGlassTint: "#2EFFFFFF"
    property string lockGlassBorder: "#59FFFFFF"
    property string lockGlassTintError: "#40FF5555"
    property string lockGlassBorderError: "#CCFF5555"
    property string lockAvatarBg: "#33FFFFFF"
    property string lockTrayTint: "#26FFFFFF"
    property string lockTrayBorder: "#3AFFFFFF"
    property string lockGlassText: "#73FFFFFF"
    property string lockAvatar: "abyss_watcher"
    
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

  Item {
    id: whiteSur_dark

    property string barBgColor: "#CC1C1C1E"
    property string buttonBorderColor: "#01000000" // near-transparent (same guard as black_flat)
    property bool buttonBorderShadow: false
    property bool onTop: true
    property string iconColor: "blue"
    property string iconPressedColor: "dark_blue"
    // Wlogout power menu
    property string wlogoutButtonBg: "#14FFFFFF"
    property string wlogoutButtonBgHover: "#330A84FF"
    property string wlogoutBorderColor: "#26FFFFFF"
    property string wlogoutSelectedBorder: "#0A84FF"
    property string wlogoutIconColor: "#F5FFFFFF"
    property string wlogoutIconSelected: "#0A84FF"
    property string wlogoutLabelColor: "#CCFFFFFF"
    // Frosted panel (power menu container)
    property string wlogoutPanelBg: "#CC1C1C1E"
    property string wlogoutPanelBorder: "#26FFFFFF"
    // Lock screen
    property string lockAccent: "#0A84FF"
    property string lockText: "#FFFFFF"
    property string lockTextDim: "#C8FFFFFF"
    property string lockTextError: "#FFD0D0"
    property string lockGlassTint: "#2EFFFFFF"
    property string lockGlassBorder: "#59FFFFFF"
    property string lockGlassTintError: "#40FF5555"
    property string lockGlassBorderError: "#CCFF5555"
    property string lockAvatarBg: "#33FFFFFF"
    property string lockAvatarBorder: "#66FFFFFF"
    property string lockTrayTint: "#26FFFFFF"
    property string lockTrayBorder: "#3AFFFFFF"
    property string lockGlassText: "#73FFFFFF"
    property string lockAvatar: "abyss_watcher"


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
