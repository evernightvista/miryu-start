/*
 * Miryu Start — https://github.com/evernightvista/miryu-start
 * Modified by naykkalak (2026) for Miryu Start, a fork of Menu 11 Next by Eisteed.
 * The original notice below is kept. This file is GPL-2.0-or-later;
 * Miryu Start as a whole is distributed under GPL-3.0-or-later.
 */
/***************************************************************************
 *   Copyright (C) 2014-2015 by Eike Hein <hein@kde.org>                   *
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 *   This program is distributed in the hope that it will be useful,       *
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of        *
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         *
 *   GNU General Public License for more details.                          *
 *                                                                         *
 *   You should have received a copy of the GNU General Public License     *
 *   along with this program; if not, write to the                         *
 *   Free Software Foundation, Inc.,                                       *
 *   51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA .        *
 ***************************************************************************/

import QtQuick 2.15
import QtQuick.Layouts 1.15

import org.kde.plasma.plasmoid

import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PC3

import org.kde.plasma.private.kicker 0.1 as Kicker
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami
import org.kde.ksvg as KSvg

PlasmoidItem {

    id: kicker

    anchors.fill: parent

    signal reset

    preferredRepresentation: compactRepresentation
    compactRepresentation: compactRepresentation
    fullRepresentation: compactRepresentation

    property Item dragSource: null
    property string searchRunnerFilter: "all"

    function action_menuedit() {
        processRunner.runMenuEditor();
    }

    Component {
        id: compactRepresentation
        CompactRepresentation {}
    }

    property QtObject globalFavorites: rootModel.favoritesModel
    property QtObject systemFavorites: rootModel.systemFavoritesModel

    Plasmoid.icon: Plasmoid.configuration.useCustomButtonImage ? Plasmoid.configuration.customButtonImage : Plasmoid.configuration.icon

    // Infobulle « Démarrer » au survol du bouton de la barre des tâches : on passe par
    // l'infobulle NATIVE de Plasma (positionnée par le shell juste au-dessus du bouton),
    // et non par un PC3.ToolTip interne, qui se plaçait au mauvais endroit.
    // Plasma 6 : toolTipMainText est une propriété DIRECTE du PlasmoidItem racine
    // (plus de préfixe « Plasmoid. », qui visait l'ancien objet attaché de Plasma 5).
    toolTipMainText: i18n("Start")

    onSystemFavoritesChanged: {
        if (systemFavorites) {
            systemFavorites.favorites = Plasmoid.configuration.favoriteSystemActions;
        }
    }

    // Fix : lors de la première session d'un nouvel utilisateur, lire les favoris
    // définis par le thème global Plasma (org.kde.plasma.desktop-layout.js →
    // kickoff.writeConfig("favorites", ...)) au lieu des favoris codés en dur
    // de favoriteApps. Deux sources sont prises en charge, par priorité :
    //   1. la clé de configuration « favorites » de CE mini-programme (écrite
    //      par le script de disposition lorsque le layout cible ce lanceur) ;
    //   2. le fichier de disposition du thème global courant, analysé pour
    //      extraire le dernier kickoff.writeConfig("favorites", [...]) trouvé.
    function parseLayoutFavorites(text) {
        const re = /writeConfig\(\s*["']favorites["']\s*,\s*\[([^\]]*)\]/g;
        let match;
        let result = [];
        while ((match = re.exec(text)) !== null) {
            // La dernière occurrence écrase les précédentes (comportement du
            // script de disposition : writeConfig écrase la valeur).
            result = match[1].split(",")
                .map(item => item.trim().replace(/^["']+|["']+$/g, ""))
                .filter(item => item.length > 0);
        }
        return result;
    }

    function portFavorites(favorites) {
        if (favorites && favorites.length > 0 && favoritesModel.count < 1) {
            favoritesModel.portOldFavorites(favorites);
        }
    }

    P5Support.DataSource {
        id: layoutFavoritesLoader

        engine: "executable"
        property bool requestPending: false

        function requestLayoutFavorites() {
            if (requestPending)
                return;
            requestPending = true;
            connectSource("miryu-read-layout-favorites");
        }

        onNewData: (source, data) => {
            disconnectSource(source);
            requestPending = false;
            const cfgFavorites = Plasmoid.configuration.favorites;
            if (cfgFavorites && cfgFavorites.length > 0) {
                // Le script de disposition a déjà écrit la clé ici : ne rien
                // écraser avec le contenu du fichier.
                portFavorites(cfgFavorites);
                return;
            }
            const favorites = parseLayoutFavorites(String(data[source] || ""));
            if (favorites.length > 0)
                portFavorites(favorites);
        }
    }

    Kicker.RootModel {
        id: rootModel

        autoPopulate: false

        appNameFormat: 0
        flat: true
        sorted: true
        showAllAppsCategorized: false // true
        showSeparators: false
        appletInterface: kicker
        showAllApps: true
        showRecentApps: true
        showRecentDocs: Plasmoid.configuration.showRecentDocs
        showPowerSession: false

        onShowRecentAppsChanged: {
            Plasmoid.configuration.showRecentApps = showRecentApps;
        }

        onShowRecentDocsChanged: {
            Plasmoid.configuration.showRecentDocs = showRecentDocs;
        }

        onRecentOrderingChanged: {
            Plasmoid.configuration.recentOrdering = recentOrdering;
        }

        Component.onCompleted: {
            favoritesModel.initForClient("org.kde.plasma.kicker.favorites.instance-" + Plasmoid.id)

            if (!Plasmoid.configuration.favoritesPortedToKAstats) {
                if (favoritesModel.count < 1) {
                    const cfgFavorites = Plasmoid.configuration.favorites;
                    if (cfgFavorites && cfgFavorites.length > 0) {
                        // Favoris posés par le script de disposition du thème global.
                        favoritesModel.portOldFavorites(cfgFavorites);
                    } else {
                        // Repli : favoris par défaut, puis lecture asynchrone du
                        // fichier de disposition du thème global courant.
                        favoritesModel.portOldFavorites(Plasmoid.configuration.favoriteApps);
                        layoutFavoritesLoader.requestLayoutFavorites();
                    }
                }
                Plasmoid.configuration.favoritesPortedToKAstats = true;
            }
        }
    }

    Connections {
        target: globalFavorites

        function onFavoritesChanged() {
            Plasmoid.configuration.favoriteApps = target.favorites;
        }
    }

    Connections {
        target: systemFavorites

        function onFavoritesChanged() {
            if (Plasmoid.configuration && target)
                Plasmoid.configuration.favoriteSystemActions = target.favorites;
        }
    }

    Kicker.RootModel {
        id: categoryRootModel

        autoPopulate: false
        appNameFormat: 0
        appletInterface: kicker
        favoritesModel: globalFavorites
        flat: false
        sorted: true
        showSeparators: false
        showAllApps: false
        showRecentApps: false
        showRecentDocs: false
        showPowerSession: false
    }

    Connections {
        target: Plasmoid.configuration

        function onFavoriteAppsChanged () {
            globalFavorites.favorites = Plasmoid.configuration.favoriteApps;
        }

        function onFavoritesChanged() {
            // Le script de disposition du thème global a écrit « favorites » :
            // appliquer immédiatement ces favoris (session en cours).
            const favorites = Plasmoid.configuration.favorites;
            if (favorites && favorites.length > 0)
                globalFavorites.favorites = favorites;
        }

        function onFavoriteSystemActionsChanged () {
            systemFavorites.favorites = Plasmoid.configuration.favoriteSystemActions;
        }

        function onHiddenApplicationsChanged(){
            rootModel.refresh();
            categoryRootModel.refresh();
        }
    }

    Kicker.RunnerModel {
         id: runnerModel

         appletInterface: kicker

         favoritesModel: globalFavorites

         runners: {
             if (kicker.searchRunnerFilter === "apps")
                 return ["krunner_services"];
             if (kicker.searchRunnerFilter === "files")
                 return ["baloosearch", "bookmarks"];
             if (kicker.searchRunnerFilter === "settings")
                 return ["krunner_systemsettings"];
             if (kicker.searchRunnerFilter === "actions")
                 return ["krunner_sessions", "krunner_powerdevil", "calculator", "unitconverter"];

             const results = ["krunner_services",
                              "krunner_systemsettings",
                              "krunner_sessions",
                              "krunner_powerdevil",
                              "calculator",
                              "unitconverter"];
             if (Plasmoid.configuration.enableShellRunner)
                 results.push("krunner_shell");
             if (Plasmoid.configuration.useExtraRunners)
                 results.push(...Plasmoid.configuration.extraRunners);
             return results;
         }
     }

    Kicker.DragHelper {
        id: dragHelper
    }

    Kicker.ProcessRunner {
        id: processRunner;
    }

    Kicker.WindowSystem {
        id: windowSystem
    }

    KSvg.FrameSvgItem {
        id : highlightItemSvg

        visible: false

        imagePath: "widgets/viewitem"
        prefix: "hover"
    }

    KSvg.FrameSvgItem {
        id : panelSvg

        visible: false

        imagePath: "widgets/panel-background"
    }

    KSvg.FrameSvgItem {
        id : scrollbarSvg

        visible: false

        imagePath: "widgets/scrollbar"
    }

    KSvg.FrameSvgItem {
        id : backgroundSvg

        visible: false

        imagePath: "dialogs/background"
    }

    PC3.Label {
        id: toolTipDelegate

        width: contentWidth
        height: undefined

        property Item toolTip

        text: toolTip ? toolTip.text : ""
        textFormat: Text.PlainText
    }

    function resetDragSource() {
        dragSource = null;
    }

    function enableHideOnWindowDeactivate() {
        kicker.hideOnWindowDeactivate = true;
    }

    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: i18n("Edit Applications…")
            icon.name: "kmenuedit"
            visible: Plasmoid.immutability !== PlasmaCore.Types.SystemImmutable
            onTriggered: processRunner.runMenuEditor()
        }
    ]

    Component.onCompleted: {
        if (Plasmoid.hasOwnProperty("activationTogglesExpanded")) {
            Plasmoid.activationTogglesExpanded = !kicker.isDash
        }

        windowSystem.focusIn.connect(enableHideOnWindowDeactivate);
        kicker.hideOnWindowDeactivate = true;

        dragHelper.dropped.connect(resetDragSource);
    }
}