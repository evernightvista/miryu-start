/*
 * Miryu Start — https://github.com/evernightvista/miryu-start
 * Part of Miryu Start (naykkalak, 2026), a fork of Menu 11 Next by Eisteed,
 * itself based on Menu 11 / Ditto Menu by adhe (GPL-2.0-or-later).
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
import QtQuick
import org.kde.plasma.plasma5support as Plasma5Support

Item {
    Plasma5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []
        onNewData: function(source, data) {
            disconnectSource(source)
        }
    }

    function openUrl(url) {
        if (url.toString().endsWith(".desktop")) {
            executable.connectSource("kioclient exec " + url)
        } else {
            executable.connectSource("xdg-open " + url)
        }
    }
    
    function runCommand(cmd) {
        executable.connectSource(cmd)
    }
}
