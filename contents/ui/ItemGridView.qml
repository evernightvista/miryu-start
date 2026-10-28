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
    // Index of the item the hovered item is waiting on before turning into a
    // folder-creation target (see folderHoverTimer): the marker gives users a
    // chance to simply reorder instead of accidentally grouping two apps.
    property int folderHoverPending: -1
    // Reordering feedback for same-grid drags: the dragged app is inserted
    // before (dropBefore) or after the item at dropTargetIndex.
    property int dropTargetIndex: -1
    property bool dropBefore: false
    // Only models exposing moveRow() can be reordered (the pinned grid does).
    readonly property bool reorderEnabled: dropEnabled && model
        && typeof model.moveRow === "function"

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
        if (!dropEnabled) {
            if (model && "dropPlaceholderIndex" in model) {
                model.dropPlaceholderIndex = -1;
            }
            clearDropFeedback();
        }
    }

    function clearDropFeedback() {
        dropTargetIndex = -1;
        dropBefore = false;
        folderCreateTarget = -1;
        folderHoverPending = -1;
        if (folderHoverTimer) {
            folderHoverTimer.stop();
        }
    }

    // Row of the last reorderable entry currently visible in the viewport
    // (used when the pointer is dropped on empty space, i.e. "append after
    // this one"). Folder tiles count: they can now sit anywhere in the order,
    // including at the very end.
    function lastVisibleEntryIndex() {
        var viewportTop = gridView.contentY;
        var viewportBottom = viewportTop + gridView.height;
        var fallback = -1;
        for (var i = count - 1; i >= 0; --i) {
            if (fallback < 0) {
                fallback = i;
            }
            var delegate = null;
            try {
                delegate = gridView.itemAtIndex(i);
            } catch (e) {
                delegate = null;
            }
            if (delegate && delegate.isBlank !== true
                    && delegate.y < viewportBottom && delegate.y + delegate.height > viewportTop) {
                return i;
            }
        }
        return fallback;
    }

    function entryAt(index) {
        try {
            if (model && typeof model.get === "function") {
                return model.get(index);
            }
        } catch (e) {}
        return null;
    }

    // Shared by onEntered/onPositionChanged of the drop area so a drop that
    // arrives without a preceding move still knows where it would land.
    function updateDragHover(x, y) {
        if (!dropEnabled || !kicker.dragSource || gridView.animating) {
            return;
        }

        var cPos = dropArea.mapToItem(gridView.contentItem, x, y);
        var item = gridView.itemAt(cPos.x, cPos.y);
        var source = kicker.dragSource;

        // ── Same-grid drag: reorder the pinned entries ────────
        if (source.parent === gridView.contentItem) {
            // Apps and folder tiles can both be reordered: the pinned order
            // interleaves them, so a folder may end up anywhere.
            var canReorder = reorderEnabled;

            if (item && item !== source && item.isBlank !== true) {
                var localX = cPos.x - item.x;
                var before = localX < item.width / 2;

                // Folder tiles keep their own drop area (add an app to the
                // folder) in the middle; their outer edges reorder around them
                // just like an app tile does.
                if (item.isFolderItem === true) {
                    folderCreateTarget = -1;
                    folderHoverPending = -1;
                    folderHoverTimer.stop();
                    if (canReorder) {
                        dropTargetIndex = item.itemIndex;
                        dropBefore = before;
                    } else {
                        dropTargetIndex = -1;
                    }
                    return;
                }

                // The outer halves of a tile are the reorder zones; only the
                // middle can become a folder.
                var centerZone = Math.abs(localX - item.width / 2) <= item.width * 0.25;

                // Folder mode belongs to a single tile's middle: leaving
                // either cancels it.
                if (folderCreateTarget >= 0
                        && (folderCreateTarget !== item.itemIndex || !centerZone)) {
                    folderCreateTarget = -1;
                }
                if (!centerZone && folderHoverPending !== -1) {
                    folderHoverPending = -1;
                    folderHoverTimer.stop();
                }

                // The side of the tile under the cursor decides whether the
                // entry lands before or after it.
                if (canReorder && folderCreateTarget !== item.itemIndex) {
                    dropTargetIndex = item.itemIndex;
                    dropBefore = before;
                }

                // Folder creation needs a deliberate pause on the middle of
                // the tile; dragging across tiles reorders.
                if (centerZone
                        && !source.isFolderItem
                        && folderCreateTarget !== item.itemIndex
                        && folderHoverPending !== item.itemIndex) {
                    folderHoverPending = item.itemIndex;
                    folderHoverTimer.restart();
                }
                return;
            }

            // Hovering the dragged tile itself: nothing to do
            if (item === source) {
                dropTargetIndex = -1;
                folderCreateTarget = -1;
                folderHoverPending = -1;
                folderHoverTimer.stop();
                return;
            }

            // Over empty space in the same grid: append at the very end
            folderCreateTarget = -1;
            folderHoverPending = -1;
            folderHoverTimer.stop();
            if (canReorder) {
                var reorderEnd = lastVisibleEntryIndex();
                if (reorderEnd >= 0 && source.itemIndex !== reorderEnd) {
                    dropTargetIndex = reorderEnd;
                    dropBefore = false;
                } else {
                    dropTargetIndex = -1;
                }
            } else {
                dropTargetIndex = -1;
            }
            return;
        }

        // ── Cross-grid drag (e.g. All apps → Pinned) ─────────
        folderCreateTarget = -1;
        folderHoverPending = -1;
        folderHoverTimer.stop();
        dropTargetIndex = -1;
        dropBefore = false;

        if (source.isFolderItem || !("dropPlaceholderIndex" in model)) {
            if ("dropPlaceholderIndex" in model) {
                model.dropPlaceholderIndex = -1;
            }
            return;
        }

        if (item) {
            if (source.GridView.view.model.favoritesModel === model
                    && !model.isFavorite(source.favoriteId)) {
                var hasPlaceholder = (model.dropPlaceholderIndex !== -1);

                model.dropPlaceholderIndex = item.itemIndex;

                if (!hasPlaceholder) {
                    gridView.currentIndex = (item.itemIndex - 1);
                }
            }
        } else if (source.GridView.view.model.favoritesModel === model
                   && !model.isFavorite(source.favoriteId)) {
            var hasPlaceholder2 = (model.dropPlaceholderIndex !== -1);

            model.dropPlaceholderIndex = hasPlaceholder2 ? model.count - 1 : model.count;

            if (!hasPlaceholder2) {
                gridView.currentIndex = (model.count - 1);
            }
        } else {
            model.dropPlaceholderIndex = -1;
            gridView.currentIndex = -1;
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

        // A drop can land without any preceding pointer movement (e.g. the drag
        // enters the grid and is released immediately), so resolve the landing
        // slot on entry as well as on movement.
        onEntered: event => {
            itemGrid.updateDragHover(event.x, event.y);
        }

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
                               itemGrid.updateDragHover(event.x, event.y);
                           }


        onExited: {
            dragScrollTimer.stop()
            dragScrollTimer.direction = 0
            itemGrid.clearDropFeedback();
            if ("dropPlaceholderIndex" in itemGrid.model) {
                itemGrid.model.dropPlaceholderIndex = -1;
                gridView.currentIndex = -1;
            }
        }

        onDropped: {
            var source = kicker.dragSource;

            // Folder creation: dropped onto another app in the same grid
            if (itemGrid.folderCreateTarget >= 0
                    && source && !source.isFolderItem
                    && source.parent === gridView.contentItem
                    && typeof rootItem !== "undefined"
                    && typeof rootItem.pinnedFoldersData !== "undefined"
                    && typeof rootItem.createPinnedFolderFromApps !== "undefined") {
                var srcId = source.favoriteId || "";
                var tgtIdx = itemGrid.folderCreateTarget;
                var tgtEntry = itemGrid.entryAt(tgtIdx);
                var tgtId = tgtEntry ? (tgtEntry.favoriteId || "") : "";
                if (!tgtId) {
                    try {
                        tgtId = itemGrid.model.data(itemGrid.model.index(tgtIdx, 0), Qt.UserRole + 3) || "";
                    } catch(e) {}
                }
                itemGrid.clearDropFeedback();
                if (srcId && tgtId && srcId !== tgtId) {
                    rootItem.createPinnedFolderFromApps(srcId, tgtId);
                }
                return;
            }

            // Same-grid reorder: move the dragged entry (app or folder tile)
            // to the marked slot.
            var targetIdx = itemGrid.dropTargetIndex;
            if (source && source.parent === gridView.contentItem
                    && itemGrid.reorderEnabled
                    && targetIdx >= 0 && targetIdx < itemGrid.count
                    && targetIdx !== source.itemIndex) {
                var from = source.itemIndex;
                var to = itemGrid.dropBefore
                        ? (from < targetIdx ? targetIdx - 1 : targetIdx)
                        : (from < targetIdx ? targetIdx : targetIdx + 1);
                itemGrid.clearDropFeedback();
                if (to >= 0 && to !== from) {
                    // Deferred: the model is reordered right after the drop
                    // event so the delegates survive the ongoing drag.
                    Qt.callLater(function() {
                        itemGrid.model.moveRow(from, to);
                    });
                }
                return;
            }

            itemGrid.clearDropFeedback();
            if (source && !source.isFolderItem
                    && source.parent !== gridView.contentItem
                    && source.GridView.view.model.favoritesModel === itemGrid.model
                    && source.favoriteId) {
                itemGrid.model.addFavorite(source.favoriteId, itemGrid.model.dropPlaceholderIndex);
                gridView.currentIndex = -1;
            }
        }

        Timer {
            id: folderHoverTimer
            interval: 600
            repeat: false
            // Fires only when the pointer has dwelled on the same tile: the
            // delegate then highlights it as a folder-creation target. Until
            // then, dragging across tiles reorders the pinned apps.
            onTriggered: {
                if (itemGrid.folderHoverPending >= 0) {
                    itemGrid.folderCreateTarget = itemGrid.folderHoverPending;
                    itemGrid.folderHoverPending = -1;
                    itemGrid.dropTargetIndex = -1;
                }
            }
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
                                           } else if (item.isFolderItem === true) {
                                               // Folder tiles have no URL of their own: give the
                                               // drag a payload so it can be reordered like an app.
                                               dragHelper.startDrag(kicker, "", "",
                                                                    "text/x-miryu-pinned-entry",
                                                                    item.entryKey || "folder");
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
