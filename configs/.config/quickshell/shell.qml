import Quickshell
import QtQuick

import "launcher" as Launcher


ShellRoot {

        Component.onCompleted: () => {
                Launcher.Controller.init();
        }
}