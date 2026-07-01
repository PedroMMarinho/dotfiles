pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property var runHistory: ({ runCounts: {}, searchHistory: [] })

    // Load history on boot

    Process {
        id: loadHistory
        command: ["bash", "-c", "cat $HOME/.cache/qs_launcher_history.json 2>/dev/null || echo '{}'"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let parsed = JSON.parse(text);
                    root.runHistory = {
                        runCounts: parsed.runCounts || {},
                        searchHistory: parsed.searchHistory || []
                    };
                } catch (e) {
                    console.log("Failed to parse launcher history:", e);
                }
            }
        }
    }
    
    function recordLaunch(appId, searchText) {
        let counts = Object.assign({}, root.runHistory.runCounts);
        
        counts[appId] = (counts[appId] || 0) + 1;

        let sortedEntries = Object.entries(counts).sort((a, b) => b[1] - a[1]);
        let cappedEntries = sortedEntries.slice(0, 25);
        
        let newCounts = {};
        for (let i = 0; i < cappedEntries.length; i++) {
            newCounts[cappedEntries[i][0]] = cappedEntries[i][1];
        }

        let searches = [...root.runHistory.searchHistory];
        if (searchText && searchText.trim() !== "") {
            let cleanText = searchText.trim();
            searches = searches.filter(s => s !== cleanText); 
            searches.unshift(cleanText); 
            searches = searches.slice(0, 25); 
        }

        root.runHistory = {
            runCounts: newCounts,
            searchHistory: searches
        };

        let jsonStr = JSON.stringify(root.runHistory);
        
        let safeJson = jsonStr.replace(/'/g, "'\\''");
        
        Quickshell.execDetached({
            command: ["bash", "-c", "echo '" + safeJson + "' > ~/.cache/qs_launcher_history.json"]
        });
    }
}