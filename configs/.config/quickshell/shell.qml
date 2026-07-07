import Quickshell
import QtQuick

import "launcher" as Launcher
import "bar" as Bar

ShellRoot {
        Bar.Bar {}
        Component.onCompleted: () => {
                Launcher.Controller.init();
        }
}
