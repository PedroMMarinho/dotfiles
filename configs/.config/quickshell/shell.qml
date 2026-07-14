//@ pragma UseQApplication
import Quickshell
import QtQuick

import "launcher" as Launcher
import "bar" as Bar
import "power" as Power
import "lock" as Lock
import "screenshot" as Screenshot

ShellRoot {
        Bar.Bar {}
        Component.onCompleted: () => {
                Launcher.Controller.init();
                Power.Controller.init();
                Lock.Controller.init();
                Screenshot.Controller.init();
        }
}
