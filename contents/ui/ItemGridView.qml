/*
 * Miryu Start — https://github.com/evernightvista/miryu-start
 * Modified by naykkalak (2026) for Miryu Start, a fork of Menu 11 Next by Eisteed.
 * The original notice below is kept. This file is GPL-2.0-or-later;
 * Miryu Start as a whole is distributed under GPL-3.0-or-later.
 */
/*
    SPDX-FileCopyrightText: 2015 Eike Hein <hein@kde.org>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick 2.15

import org.kde.kquickcontrolsaddons 2.0
import org.kde.ksvg 1.0 as KSvg
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras 2.0 as PlasmaExtras
import org.kde.kirigami 2.20 as Kirigami

FocusScope {
    id: itemGrid

    signal keyNavLeft
    signal keyNavRight
    signal keyNavUp
    signal keyNavDown
    signal wheelUnhandled(real delta)

    signal itemActivated(int index, string actionId, string argument)
    signal folderEditRequested(int index)
    // Fenestra : clic sur un en-tête de lettre (index alphabétique cliquable, comme KDE)
    signal letterActivated(string letter)

    property bool _folderEditPressed: false
    property bool _letterHovered: false
    property Item hoveredLetter: null
    property bool dragEnabled: true
    property bool dropEnabled: false
    property bool showLabels: true
    property bool labels2lines: false
    property bool showNewTag: false
    // liste de favoris à utiliser pour le clic droit à la place de celle du modèle
    // (null par défaut : aucun changement pour les grilles qui fonctionnent déjà)
    property var favoritesModelOverride: null
    property int itemColumns
    // True for the pinned-favorites grid: its delegates treat "folder" entries as
    // pinned folders (2×2 app mosaic) and open the pinned folder context menu.
    property bool pinnedGrid: false
    // Folder creation via drag: index of the item being hovered as folder target
    property int folderCreateTarget: -1

    property alias currentIndex: gridView.currentIndex
    property alias currentItem: gridView.currentItem
    property alias contentItem: gridView.contentItem
    property alias count: gridView.count
    property alias model: gridView.model

    property alias cellWidth: gridView.cellWidth
    property alias cellHeight: gridView.cellHeight
    property int iconSize

    property alias contentY: gridView.contentY
    property alias contentHeight: gridView.contentHeight

    property var horizontalScrollBarPolicy: PlasmaComponents.ScrollBar.AlwaysOff
    property var verticalScrollBarPolicy: PlasmaComponents.ScrollBar.AlwaysOff
    property bool bypassArrowNav: false
    // lignes des recommandations (icône + nom + « date · dossier », infobulle chemin complet)
    property bool recentDocsMode: false
    // surlignement blanc 50 % + bordure (sinon bleu d'origine)
    property bool whiteHighlight: false
    // raccourcit le surlignement à droite (px)
    property int highlightRightPad: 0
    // version pleine largeur (page « Nos recommandations ») : heure à droite, chemin sous le nom
    property bool recentDocsWide: false
    // instant de la dernière touche de navigation (sert à ignorer les « sorties de souris » dues au défilement)
    function _keyNavRecently() {
        return typeof rootItem !== "undefined" && rootItem.keyNavRecently();
    }
    onDropEnabledChanged: {
        if (!dropEnabled && "dropPlaceHolderIndex" in model) {
            model.dropPlaceHolderIndex = -1;
        }
    }

    onFocusChanged: {
        //if (!focus && !root.keyEventProxy.activeFocus) {
        if (!focus) {
            currentIndex = -1;
        }
    }

    // When the grid becomes visible (menu opened) with the pointer already
    // over an item, neither onPositionChanged nor HoverHandler may fire on
    // the first frame. Reset lastX/lastY so updatePositionProperties runs,
    // then nudge the hover area on the next frame to pick up the cursor.
    onVisibleChanged: {
        if (visible) {
            hoverArea.lastX = -1;
            hoverArea.lastY = -1;
            hoverRefreshTimer.restart();
        }
    }

    function currentRow() {
        if (currentIndex === -1) {
            return -1;
        }

        return Math.floor(currentIndex / Math.floor(width / itemGrid.cellWidth));
    }

    function currentCol() {
        if (currentIndex === -1) {
            return -1;
        }

        return currentIndex - (currentRow() * Math.floor(width / itemGrid.cellWidth));
    }

    function lastRow() {
        var columns = Math.floor(width / itemGrid.cellWidth);
        return Math.ceil(count / columns) - 1;
    }

    function tryActivate(row, col) {
        if (count) {
            var columns = Math.floor(width / itemGrid.cellWidth);
            var rows = Math.ceil(count / columns);
            row = Math.min(row, rows - 1);
            col = Math.min(col, columns - 1);
            currentIndex = Math.min(row ? ((Math.max(1, row) * columns) + col)
                                        : col,
                                    count - 1);

            focus = true;
        }
    }

    function forceLayout() {
        gridView.forceLayout();
    }

    function positionAtIndex(idx) {
        gridView.positionViewAtIndex(idx, GridView.Beginning);
    }

    ActionMenu {
        id: actionMenu

        onActionClicked: {
            visualParent.actionTriggered(actionId, actionArgument);
        }
    }

    DropArea {
        id: dropArea

        width: itemGrid.width
    height: itemGrid.height
        //anchors.fill: parent

        onPositionChanged: event => {
                               if (kicker.dragSource) {
                                   var ez = 52
                                   if (event.y < ez) {
                                       dragScrollTimer.direction = -1
                                       if (!dragScrollTimer.running) dragScrollTimer.start()
                                   } else if (event.y > height - ez) {
                                       dragScrollTimer.direction = 1
                                       if (!dragScrollTimer.running) dragScrollTimer.start()
                                   } else {
                                       dragScrollTimer.stop()
                                       dragScrollTimer.direction = 0
                                   }
                               }
                               if (!itemGrid.dropEnabled || gridView.animating || !kicker.dragSource) {
                                   return;
                               }

                               var x = Math.max(0, event.x - (width % itemGrid.cellWidth));
                               var cPos = mapToItem(gridView.contentItem, x, event.y);
                               var item = gridView.itemAt(cPos.x, cPos.y);

                               // Same-grid drag: hover over another app → folder creation mode
                               if (item && kicker.dragSource.parent === gridView.contentItem
                                       && item !== kicker.dragSource
                                       && typeof rootItem !== "undefined"
                                       && typeof rootItem.pinnedFoldersData !== "undefined") {
                                   if (itemGrid.folderCreateTarget !== item.itemIndex) {
                                       itemGrid.folderCreateTarget = item.itemIndex;
                                       folderHoverTimer.restart();
                                   }
                                   return;
                               }

                               // Not hovering an item for folder creation: reset folder mode
                               itemGrid.folderCreateTarget = -1;
                               folderHoverTimer.stop();

                               if (item) {
                                   if (kicker.dragSource.parent === gridView.contentItem) {
                                       if (item !== kicker.dragSource) {
                                           item.GridView.view.model.moveRow(dragSource.itemIndex, item.itemIndex);
                                       }
                                   } else if (kicker.dragSource.GridView.view.model.favoritesModel === itemGrid.model
                                              && !itemGrid.model.isFavorite(kicker.dragSource.favoriteId)) {
                                       var hasPlaceholder = (itemGrid.model.dropPlaceholderIndex !== -1);

                                       itemGrid.model.dropPlaceholderIndex = item.itemIndex;

                                       if (!hasPlaceholder) {
                                           gridView.currentIndex = (item.itemIndex - 1);
                                       }
                                   }
                               } else if (kicker.dragSource.parent !== gridView.contentItem
                                          && kicker.dragSource.GridView.view.model.favoritesModel === itemGrid.model
                                          && !itemGrid.model.isFavorite(kicker.dragSource.favoriteId)) {
                                   var hasPlaceholder = (itemGrid.model.dropPlaceholderIndex !== -1);

                                   itemGrid.model.dropPlaceholderIndex = hasPlaceholder ? itemGrid.model.count - 1 : itemGrid.model.count;

                                   if (!hasPlaceholder) {
                                       gridView.currentIndex = (itemGrid.model.count - 1);
                                   }
                               } else {
                                   itemGrid.model.dropPlaceholderIndex = -1;
                                   gridView.currentIndex = -1;
                               }
                           }


        onExited: {
            dragScrollTimer.stop()
            dragScrollTimer.direction = 0
            itemGrid.folderCreateTarget = -1;
            folderHoverTimer.stop();
            if ("dropPlaceholderIndex" in itemGrid.model) {
                itemGrid.model.dropPlaceholderIndex = -1;
                gridView.currentIndex = -1;
            }
        }

        onDropped: {
            // Folder creation: dropped onto another app in the same grid
            if (itemGrid.folderCreateTarget >= 0
                    && kicker.dragSource && kicker.dragSource.parent === gridView.contentItem
                    && typeof rootItem !== "undefined"
                    && typeof rootItem.pinnedFoldersData !== "undefined"
                    && typeof rootItem.createPinnedFolderFromApps !== "undefined") {
                var srcId = kicker.dragSource.favoriteId || "";
                var tgtIdx = itemGrid.folderCreateTarget;
                var tgtId = "";
                try {
                    if (typeof itemGrid.model.get === "function") {
                        var entry = itemGrid.model.get(tgtIdx);
                        tgtId = entry ? (entry.favoriteId || "") : "";
                    } else {
                        tgtId = itemGrid.model.data(itemGrid.model.index(tgtIdx, 0), Qt.UserRole + 3) || "";
                    }
                } catch(e) {}
                itemGrid.folderCreateTarget = -1;
                folderHoverTimer.stop();
                if (srcId && tgtId && srcId !== tgtId) {
                    rootItem.createPinnedFolderFromApps(srcId, tgtId);
                }
                return;
            }
            itemGrid.folderCreateTarget = -1;
            folderHoverTimer.stop();
            if (kicker.dragSource && kicker.dragSource.parent !== gridView.contentItem && kicker.dragSource.GridView.view.model.favoritesModel === itemGrid.model) {
                itemGrid.model.addFavorite(kicker.dragSource.favoriteId, itemGrid.model.dropPlaceholderIndex);
                gridView.currentIndex = -1;
            }
        }

        Timer {
            id: folderHoverTimer
            interval: 350
            repeat: false
            // When fired, folderCreateTarget is already set; the delegate highlights it.
            // A short delay distinguishes "reorder" (quick drop) from "create folder" (hover).
        }

        // Re-evaluate hover when the grid becomes visible so the item under a
        // stationary cursor is highlighted without waiting for a mouse move.
        Timer {
            id: hoverRefreshTimer
            interval: 10
            repeat: false
            onTriggered: {
                if (!itemGrid.visible) return;
                if (typeof rootItem !== "undefined" && rootItem.keyNavRecently()) return;
                if (!hoverArea.containsMouse) return;
                hoverArea.lastX = -1;
                hoverArea.lastY = -1;
                hoverArea.updatePositionProperties(hoverArea.mouseX, hoverArea.mouseY);
            }
        }

        Timer {
            id: resetAnimationDurationTimer

            interval: 120
            repeat: false

            onTriggered: {
                gridView.animationDuration = interval - 20;
            }
        }

        Timer {
            id: dragScrollTimer
            interval: 16
            repeat: true
            property int direction: 0
            onTriggered: {
                var maxY = Math.max(0, gridView.contentHeight - gridView.height)
                if (direction === -1) gridView.contentY = Math.max(0, gridView.contentY - 8)
                else if (direction === 1) gridView.contentY = Math.min(maxY, gridView.contentY + 8)
            }
        }

        Component{
            id: aItemGridDelegate2
            ItemGridDelegateColumns {
                showLabel: showLabels
                labels2lines: itemGrid.labels2lines
                itemColumns: itemGrid.itemColumns
                iconSize: itemGrid.iconSize
            }
        }
        Component{
            id: aItemGridDelegate
            ItemGridDelegate {
                showLabel: itemGrid.showLabels
                showNewTag: itemGrid.showNewTag
                labels2lines: itemGrid.labels2lines
                itemColumns: itemGrid.itemColumns
                iconSize: itemGrid.iconSize
            }
        }

        Component {
            id: aRecentDocDelegate
            RecentDocDelegate {
                iconSize: itemGrid.iconSize
            }
        }

        PlasmaComponents.ScrollView {
            id: scrollArea

            //anchors.fill: parent
            width: itemGrid.width
            height: itemGrid.height


            focus: true

            PlasmaComponents.ScrollBar.horizontal.policy: itemGrid.horizontalScrollBarPolicy
            PlasmaComponents.ScrollBar.vertical.policy: itemGrid.verticalScrollBarPolicy

            GridView {
                id: gridView

                // transmet la liste de favoris imposée à l'enveloppe (itemGrid), pour le clic droit
                property var favoritesModelOverride: itemGrid.favoritesModelOverride
                // transmet le drapeau « grille des favoris épinglés » aux délégués
                // (GridView.view pointe sur ce GridView interne, pas sur itemGrid)
                property bool pinnedGrid: itemGrid.pinnedGrid

                width:  itemGrid.width                
                height: itemGrid.height

                signal itemContainsMouseChanged(bool containsMouse)

                property int iconSize: Kirigami.Units.iconSizes.huge

                property bool animating: false
                property int animationDuration: itemGrid.dropEnabled ? resetAnimationDurationTimer.interval : 0

                focus: true

                currentIndex: -1

                move: Transition {
                    enabled: itemGrid.dropEnabled

                    SequentialAnimation {
                        PropertyAction { target: gridView; property: "animating"; value: true }

                        NumberAnimation {
                            duration: gridView.animationDuration
                            properties: "x, y"
                            easing.type: Easing.OutQuad
                        }

                        PropertyAction { target: gridView; property: "animating"; value: false }
                    }
                }

                moveDisplaced: Transition {
                    enabled: itemGrid.dropEnabled

                    SequentialAnimation {
                        PropertyAction { target: gridView; property: "animating"; value: true }

                        NumberAnimation {
                            duration: gridView.animationDuration
                            properties: "x, y"
                            easing.type: Easing.OutQuad
                        }

                        PropertyAction { target: gridView; property: "animating"; value: false }
                    }
                }

                // Animate items appearing (e.g. app dragged out of a folder
                // reappears in the pinned grid).
                add: Transition {
                    enabled: true
                    NumberAnimation {
                        property: "opacity"
                        from: 0
                        to: 1
                        duration: 180
                        easing.type: Easing.OutCubic
                    }
                    NumberAnimation {
                        property: "scale"
                        from: 0.6
                        to: 1
                        duration: 180
                        easing.type: Easing.OutBack
                    }
                }

                // Animate items disappearing (e.g. app dragged into a folder
                // is filtered out of the pinned grid).
                remove: Transition {
                    enabled: true
                    NumberAnimation {
                        property: "opacity"
                        from: 1
                        to: 0
                        duration: 150
                        easing.type: Easing.InCubic
                    }
                    NumberAnimation {
                        property: "scale"
                        from: 1
                        to: 0.6
                        duration: 150
                        easing.type: Easing.InCubic
                    }
                }

                keyNavigationWraps: false
                boundsBehavior: Flickable.StopAtBounds

                // Molette (souris) : le GridView avalerait la molette même sans rien à faire
                // défiler ; on défile la grille à la main et, en bout de liste, on relaie
                // au défilement du menu (signal wheelUnhandled).
                WheelHandler {
                    id: wheelForward
                    target: null
                    onWheel: event => {
                        event.accepted = true;
                        var maxY = Math.max(0, gridView.contentHeight - gridView.height);
                        var pixels = (event.angleDelta.y / 120) * Kirigami.Units.gridUnit * 3;
                        var versLeHaut = pixels > 0;
                        if (maxY <= 0
                            || (versLeHaut && gridView.contentY <= 0)
                            || (!versLeHaut && gridView.contentY >= maxY)) {
                            itemGrid.wheelUnhandled(pixels);
                        } else {
                            gridView.contentY = Math.max(0, Math.min(maxY, gridView.contentY - pixels));
                        }
                    }
                }

                delegate: itemGrid.recentDocsMode ? aRecentDocDelegate : (itemColumns == 1 ? aItemGridDelegate : aItemGridDelegate2)
                highlight: Item {
                    Rectangle {
                        anchors.fill: parent
                        anchors.rightMargin: itemGrid.highlightRightPad
                        color: itemGrid.whiteHighlight ? (Kirigami.Theme.textColor.hslLightness > 0.5 ? "#26ffffff" : "#80ffffff")
                        : Qt.rgba(Kirigami.Theme.highlightColor.r,
                        Kirigami.Theme.highlightColor.g,
                        Kirigami.Theme.highlightColor.b, 0.18)
                        border.width: itemGrid.whiteHighlight ? 1 : 0
                        border.color: (Kirigami.Theme.textColor.hslLightness > 0.5 ? "#1affffff" : "#14000000")
                        radius: itemGrid.whiteHighlight ? 5 : 6
                    }
                }

                highlightFollowsCurrentItem: true
                highlightMoveDuration: 0

                onCurrentIndexChanged: {
                    if (currentIndex !== -1) {
                        hoverArea.hoverEnabled = false;
                        focus = true;
                    }
                }

                onCountChanged: {
                    animationDuration = 0;
                    resetAnimationDurationTimer.start();
                }

                onModelChanged: {
                    currentIndex = -1;
                }

                Keys.onLeftPressed: event => {
                    if (typeof rootItem !== "undefined") rootItem.lastNavKeyTime = Date.now();
                                        if (itemGrid.currentCol() !== 0) {
                                            event.accepted = true;
                                            moveCurrentIndexLeft();
                                        } else {
                                            itemGrid.keyNavLeft();
                                        }
                                    }

                Keys.onRightPressed: event => {
                    if (typeof rootItem !== "undefined") rootItem.lastNavKeyTime = Date.now();
                                        var columns = Math.floor(width / cellWidth);
                                        if (itemGrid.currentCol() !== columns - 1 && currentIndex !== count -1) {
                                            event.accepted = true;
                                            moveCurrentIndexRight();
                                        } else {
                                            itemGrid.keyNavRight();
                                        }
                                    }

                Keys.onUpPressed: event => {
                    if (typeof rootItem !== "undefined") rootItem.lastNavKeyTime = Date.now();
                    if (bypassArrowNav) {
                        keyNavUp()
                        event.accepted = true
                    } else if (currentRow() !== 0) {
                        moveCurrentIndexUp()
                        event.accepted = true
                    } else {
                        keyNavUp()
                    }
                }

                Keys.onDownPressed: event => {
                    if (typeof rootItem !== "undefined") rootItem.lastNavKeyTime = Date.now();
                    if (bypassArrowNav) {
                        keyNavDown()
                        event.accepted = true
                    } else if (currentRow() < lastRow()) {
                        var columns = Math.floor(width / cellWidth)
                        var newIndex = currentIndex + columns
                        currentIndex = Math.min(newIndex, count - 1)
                        positionViewAtIndex(currentIndex, GridView.Contain)
                        event.accepted = true
                    } else {
                        keyNavDown()
                    }
                }

                onItemContainsMouseChanged: containsMouse => {
                                                if (!containsMouse) {
                                                    // le défilement au clavier fait sortir l'élément du curseur immobile :
                                                    // on garde alors la sélection au clavier
                                                    if (itemGrid._keyNavRecently()) {
                                                        return;
                                                    }
                                                    if (!actionMenu.opened) {
                                                        gridView.currentIndex = -1;
                                                    }

                                                    hoverArea.pressX = -1;
                                                    hoverArea.pressY = -1;
                                                    hoverArea.lastX = -1;
                                                    hoverArea.lastY = -1;
                                                    hoverArea.pressedItem = null;
                                                    hoverArea.pressedLetter = null;
                                                    itemGrid._letterHovered = false;
                                                    itemGrid.hoveredLetter = null;
                                                    hoverArea.hoverEnabled = true;
                                                }
                                            }
            }
        }

        MouseArea {
            id: hoverArea
            cursorShape: Qt.ArrowCursor
    
            //anchors.fill: parent
            width:  itemGrid.width - Kirigami.Units.gridUnit
            height: itemGrid.height

            property int pressX: -1
            property int pressY: -1
            property int lastX: -1
            property int lastY: -1
            property Item pressedItem: null
            // Fenestra : en-tête de lettre sous le curseur au moment de l'appui
            property Item pressedLetter: null

            acceptedButtons: Qt.LeftButton | Qt.RightButton

            hoverEnabled: true

            // When the menu opens with the pointer already over the grid,
            // onEntered fires so we can highlight the item under the cursor
            // without waiting for a mouse move.
            onEntered: {
                if (typeof rootItem !== "undefined" && rootItem.keyNavRecently()) return;
                lastX = -1;
                lastY = -1;
                updatePositionProperties(mouseX, mouseY);
            }

            function updatePositionProperties(x, y) {
                // Prevent hover event synthesis in QQuickWindow interfering
                // with keyboard navigation by ignoring repeated events with
                // identical coordinates. As the work done here would be re-
                // dundant in any case, these are safe to ignore.
                if (lastX === x && lastY === y) {
                    return;
                }

                lastX = x;
                lastY = y;

                var cPos = mapToItem(gridView.contentItem, x, y);
                var item = gridView.itemAt(cPos.x, cPos.y);

                if (item && item.isLetterHeader === true) {
                    // Fenestra : en-tête de lettre = index alphabétique cliquable (comme
                    // KDE Kickoff). On le retient pour émettre « letterActivated » au
                    // relâchement ; il ne devient jamais l'élément courant (pas d'action).
                    itemGrid._letterHovered = true;
                    itemGrid.hoveredLetter = item;
                    pressedLetter = item;
                    pressedItem = null;
                    gridView.currentIndex = -1;
                    return item;
                }

                itemGrid._letterHovered = false;
                itemGrid.hoveredLetter = null;
                pressedLetter = null;

                if (!item || item.isBlank === true) {
                    gridView.currentIndex = -1;
                    pressedItem = null;
                } else {
                    itemGrid.focus = (item.itemIndex !== -1)
                    itemGrid.forceActiveFocus() //<>
                    gridView.currentIndex = item.itemIndex;
                }

                return item;
            }

            onExited: {
                itemGrid._letterHovered = false;
                itemGrid.hoveredLetter = null;
                pressedLetter = null;
            }

            onPressed: mouse => {
                           mouse.accepted = true;

                           updatePositionProperties(mouse.x, mouse.y);

                           pressX = mouse.x;
                           pressY = mouse.y;

                           if (mouse.button === Qt.RightButton) {
                               if (pressedLetter) {
                                   // Fenestra : un en-tête de lettre n'a pas de menu contextuel
                               } else if (gridView.currentItem) {
                                   if (gridView.currentItem.hasActionList) {
                                       var mapped = mapToItem(gridView.currentItem, mouse.x, mouse.y);
                                       gridView.currentItem.openActionMenu(mapped.x, mapped.y);
                                   }
                               } else {
                                   var mapped = mapToItem(rootItem, mouse.x, mouse.y);
                                   contextMenu.open(mapped.x, mapped.y);
                               }
                           } else {
                               var ci = gridView.currentItem;
                               if (ci && ("folderEditZoneHovered" in ci) && ci.folderEditZoneHovered) {
                                   itemGrid._folderEditPressed = true;
                                   pressedItem = null;
                               } else {
                                   itemGrid._folderEditPressed = false;
                                   pressedItem = ci;
                               }
                           }
                       }

            onReleased: mouse => {
                            mouse.accepted = true;
                            updatePositionProperties(mouse.x, mouse.y);

                            if (itemGrid._folderEditPressed) {
                                itemGrid._folderEditPressed = false;
                                if (!dragHelper.dragging) {
                                    var editCI = gridView.currentItem;
                                    if (editCI && ("isFolderItem" in editCI) && editCI.isFolderItem) {
                                        itemGrid.folderEditRequested(editCI.itemIndex);
                                    }
                                }
                                pressX = pressY = -1;
                                pressedItem = null;
                                return;
                            }

                            if (!dragHelper.dragging) {
                                if (pressedLetter) {
                                    // Fenestra : navigation alphabétique — le clic sur une
                                    // lettre fait défiler la page jusqu'à sa section.
                                    itemGrid.letterActivated(pressedLetter.letterText);
                                    pressX = pressY = -1;
                                    pressedLetter = null;
                                    pressedItem = null;
                                    return;
                                }
                                if (pressedItem) {
                                    if (pressedItem.favoriteId && pressedItem.favoriteId !== "" &&
                                        typeof rootItem !== "undefined") {
                                        rootItem.recordLaunch(pressedItem.favoriteId);
                                    }
                                    if ("trigger" in gridView.model) {
                                        gridView.model.trigger(pressedItem.itemIndex, "", null);
                                        // Don't close the menu when opening a folder
                                        var isFolder = ("isFolderItem" in pressedItem) && pressedItem.isFolderItem;
                                        if (!isFolder) root.toggle();
                                    }

                                    itemGrid.itemActivated(pressedItem.itemIndex, "", null);
                                }
                                // Fenestra : clic dans le vide sans fermeture (le menu d'origine se fermait ici)
                            }

                            pressX = pressY = -1;
                            pressedItem = null;
                        }

            onPositionChanged: mouse => {
                                   // le défilement (clavier) fait « bouger » la souris immobile : on ignore ces événements
                                   if (pressedItem === null && itemGrid._keyNavRecently()) {
                                       return;
                                   }
                                   var item = pressedItem? pressedItem : updatePositionProperties(mouse.x, mouse.y);

                                   if (gridView.currentIndex !== -1) {
                                       if (itemGrid.dragEnabled && pressX !== -1 && dragHelper.isDrag(pressX, pressY, mouse.x, mouse.y)) {
                                           if ("pluginName" in item.m) {
                                               dragHelper.startDrag(kicker, item.url, item.icon,
                                                                    "text/x-plasmoidservicename", item.m.pluginName);
                                           } else {
                                               // console.log(kicker, item.url, item.icon);
                                               // dragHelper.startDrag(kicker, item.url, item.icon);
                                               dragHelper.startDrag(kicker,item.url);
                                           }
                                           kicker.dragSource = item;
                                           pressX = -1;
                                           pressY = -1;
                                       }
                                   }
                               }
        }
    }
}
