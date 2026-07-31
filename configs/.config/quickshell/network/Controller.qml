pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Networking
import "root:/"

// Announces internet reachability changes.
//
// Deliberately not part of the Wifi bar block: NetworkManager's connectivity
// check is session-wide, so this covers the ethernet ports too, and "am I
// online" is not something a bar widget should own.
Singleton {
    id: root

    // The declarative binding that kicks off Networking's lazy init. Until it
    // settles (~1s) connectivity reads Unknown, which _evaluate ignores.
    readonly property int connectivity: Networking.connectivity

    // Category, not raw enum: a disconnect walks Full -> Limited -> None and a
    // reconnect walks None -> Portal -> Full, so collapsing to
    // online/portal/offline keeps one event from producing three popups.
    readonly property string category: {
        if (root.connectivity === NetworkConnectivity.Full)
            return "online";
        if (root.connectivity === NetworkConnectivity.Portal)
            return "portal";
        if (root.connectivity === NetworkConnectivity.Unknown)
            return "";
        return "offline";
    }

    // SSID of the connected wifi network, empty on ethernet or when down.
    readonly property string ssid: {
        const wifi = [...Networking.devices.values].find(d => d.type === DeviceType.Wifi);
        if (!wifi)
            return "";
        const net = [...wifi.networks.values].find(n => n.connected);
        return net ? net.name : "";
    }

    // Last category actually announced. Empty means we have not seen a real
    // value yet, so the first one is adopted as a silent baseline -- otherwise
    // every shell reload would greet you with a connectivity popup.
    property string announced: ""
    property string pending: ""

    onCategoryChanged: root.evaluate()

    function evaluate() {
        if (root.category === "")
            return;

        // Flapped back to where we already are before the settle timer fired.
        if (root.category === root.announced) {
            settle.stop();
            root.pending = "";
            return;
        }

        root.pending = root.category;
        settle.restart();
    }

    // Roaming between APs and DHCP renewals dip through Limited for a moment.
    // Waiting for the state to hold avoids a lost/restored pair every time.
    Timer {
        id: settle
        interval: 3000
        onTriggered: root.announce()
    }

    function announce() {
        const cat = root.pending;
        if (cat === "" || cat === root.announced)
            return;

        const baseline = root.announced === "";
        root.announced = cat;
        root.pending = "";

        if (baseline)
            return;

        if (cat === "online") {
            Notify.send("Internet connected",
                        root.ssid ? "Connected to " + root.ssid : "",
                        "network-wireless-connected-symbolic", "normal");
        } else if (cat === "portal") {
            Notify.send("Sign-in required",
                        "This network wants you to log in before it lets you out",
                        "network-wireless-no-route-symbolic", "normal");
        } else {
            Notify.send("No internet connection",
                        root.ssid ? "Still on " + root.ssid + ", but nothing gets through" : "",
                        "network-wireless-offline-symbolic", "normal");
        }
    }

    function init() {
    }
}
