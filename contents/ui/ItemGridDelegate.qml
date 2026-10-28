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

import QtQuick

import org.kde.plasma.components 3.0 as PlasmaComponents3
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami 2.20 as Kirigami
import QtQuick.Layouts 1.1
import "code/tools.js" as Tools

Item {
    id: item

    width: GridView.view.cellWidth
    height: GridView.view.cellHeight
    clip: !isLetterHeader // le bandeau de la lettre déborde volontairement de la cellule

    enabled: !model.disabled

    // Pop-in animation: plays when this delegate is created or recycled with
    // new data (e.g. an app dragged out of a folder reappears in the grid).
    // The GridView add/remove transitions don't fire because KSortFilterProxyModel
    // invalidates with a full model reset, so we animate at the delegate level.
    SequentialAnimation on opacity {
        id: popInOpacityAnim
        running: false
        NumberAnimation { from: 0; to: 1; duration: 180; easing.type: Easing.OutCubic }
    }
    SequentialAnimation on scale {
        id: popInScaleAnim
        running: false
        NumberAnimation { from: 0.6; to: 1; duration: 180; easing.type: Easing.OutBack }
    }

    onFavoriteIdChanged: {
        popInOpacityAnim.restart();
        popInScaleAnim.restart();
    }
    Component.onCompleted: {
        popInOpacityAnim.start();
        popInScaleAnim.start();
    }

    property int iconSize
    property bool showLabel: true
    // tag « Nouveauté » (activé seulement par la grille de la fenêtre de catégorie)
    property bool showNewTag: false
    readonly property bool isNewTag: showNewTag && !isFolderItem && !isIndented
                                     && favoriteId !== "" && typeof rootItem !== "undefined"
                                     && rootItem.newApps !== undefined && !!rootItem.newApps[favoriteId]

    // itemIndex: the delegate's row position. For ListModel-backed grids we also
    // expose an explicit `row` role; for QAbstractItemModel grids we fall back to
    // the delegate's context `index` property (always equals the row position).
    property int itemIndex: (model.row !== undefined && model.row !== null && model.row !== "") ? model.row : index
    property string favoriteId: model.favoriteId !== undefined ? model.favoriteId : ""
    property url url: model.url !== undefined ? model.url : ""
    property variant icon: model.decoration !== undefined ? model.decoration : ""
    property var m: model
    property bool isFolderItem: model.itemType === "folder"
    property bool isIndented:   model.indented === true
    // Capture folder index at item scope so nested Repeaters (which shadow `model`)
    // can still read it via `item.folderIdx`.
    property int folderIdx: model.folderIdx !== undefined ? model.folderIdx : -1

    property bool hasActionList: {
        if (isFolderItem) return true;
        return (model.favoriteId !== null) || (("hasActionList" in model) && (model.hasActionList === true));
    }

    property int itemColumns
    property bool labels2lines: false
    Accessible.role: Accessible.MenuItem
    Accessible.name: model.display

    function openActionMenu(x, y) {
        if (isFolderItem) {
            // PlasmaExtras.Menu.open(x, y) positions relative to visualParent;
            // without it the menu falls back to the QObject parent (rootItem)
            // and pops up at the window's top-left corner.
            if (item.isPinnedFolder) {
                folderContextMenu.visualParent = item;
                folderContextMenu.targetIndex = item.folderIdx;
                folderContextMenu.open(x || 0, y || 0);
            } else {
                allAppsFolderContextMenu.visualParent = item;
                allAppsFolderContextMenu.targetIndex = item.folderIdx;
                allAppsFolderContextMenu.open(x || 0, y || 0);
            }
            return;
        }
        // Resolve the desktop action list lazily, at menu-open time (see
        // rootItem.actionListForEntry in MenuRepresentation.qml): a QVariantList
        // stored in a QML ListModel comes back as a nested sub-model, not an
        // array, and may lose C++-typed action arguments — so prefer reading
        // ActionListRole straight from the Kicker C++ source model, with the
        // stored copy only as a last-resort fallback.
        var actionList = (typeof rootItem !== "undefined" && rootItem.actionListForEntry)
                         ? rootItem.actionListForEntry(item.m)
                         : Tools.asActionArray(model.actionList);
        Tools.fillActionMenu(i18n, actionMenu, actionList, (GridView.view.favoritesModelOverride || GridView.view.model.favoritesModel), model.favoriteId);
        actionMenu.visualParent = item;
        actionMenu.open(x, y);
    }

    function actionTriggered(actionId, actionArgument) {
        var close = (Tools.triggerAction(GridView.view.model, item.itemIndex, actionId, actionArgument) === true);

        if (close) {
            root.toggle();
        }
    }
    // Left indent for expanded folder children
    property real indentOffset: isIndented ? Kirigami.Units.gridUnit * 1.5 : 0

    // Folder drop highlight ring
    Rectangle {
        anchors.fill: parent
        anchors.margins: 2
        radius: Kirigami.Units.smallSpacing
        visible: isFolderItem && folderDropArea.containsDrag
        color: root.colorWithAlpha(Kirigami.Theme.highlightColor, 0.18)
        border.width: 2
        border.color: Kirigami.Theme.highlightColor
        z: 1
    }

    // Folder-creation target highlight (drag one app onto another)
    Rectangle {
        id: folderCreateHighlight
        anchors.fill: parent
        anchors.margins: 2
        radius: Kirigami.Units.smallSpacing + 2
        visible: (typeof itemGrid !== "undefined") && itemGrid.folderCreateTarget === item.itemIndex
        color: root.colorWithAlpha(Kirigami.Theme.highlightColor, 0.22)
        border.width: 2
        border.color: Kirigami.Theme.highlightColor
        opacity: visible ? 1 : 0
        scale: visible ? 1 : 0.8
        z: 1

        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack } }

        // Subtle pulse while waiting for the drop
        SequentialAnimation on opacity {
            running: folderCreateHighlight.visible
            loops: Animation.Infinite
            NumberAnimation { to: 0.5; duration: 500; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1; duration: 500; easing.type: Easing.InOutSine }
        }
    }

    // Reorder insertion marker: a bar on the side of the tile where the
    // dragged pinned app would be inserted (same-grid drag).
    Rectangle {
        readonly property bool active: (typeof itemGrid !== "undefined")
                                       && itemGrid.dropTargetIndex === item.itemIndex
        visible: active && !item.isLetterHeader && !item.isBlank
        x: active ? (itemGrid.dropBefore ? 0 : item.width - width) : 0
        y: Kirigami.Units.smallSpacing
        width: 3
        height: Math.max(0, item.height - y * 2)
        radius: width / 2
        color: Kirigami.Theme.highlightColor
        z: 2
    }

    // Drop-onto-folder area (only active for folder items). The left/right
    // edges are left free so the grid's drop area can reorder the folder tile
    // there (a folder is a reorderable entry, not just a drop target).
    DropArea {
        id: folderDropArea
        anchors.fill: parent
        anchors.leftMargin: Math.round(parent.width * 0.18)
        anchors.rightMargin: Math.round(parent.width * 0.18)
        enabled: isFolderItem
                 && !(typeof kicker !== "undefined" && kicker.dragSource
                      && kicker.dragSource.isFolderItem === true)
        onDropped: {
            var src = kicker.dragSource;
            if (!src || !src.favoriteId || src.favoriteId === "") return;
            if (src.m && src.m.itemType === "folder") return;
            var favId = src.favoriteId;
            var fi = item.folderIdx;
            var isPinned = item.isPinnedFolder;
            var dataArr = isPinned ? rootItem.pinnedFoldersData : rootItem.allAppsFoldersData;
            if (fi < 0 || fi >= dataArr.length) return;
            var folders = dataArr.slice();
            var folder = folders[fi];
            if (!folder || (folder.items && folder.items.indexOf(favId) >= 0)) return;
            var newItems = (folder.items || []).concat([favId]);
            folders[fi] = { name: folder.name, items: newItems, createdAt: folder.createdAt || 0 };
            if (isPinned) {
                rootItem.pinnedFoldersData = folders;
                rootItem.saveFolders();
            } else {
                rootItem.allAppsFoldersData = folders;
                rootItem.saveAllAppsFolders();
            }
        }
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse
        onWheel: {
            if (typeof scrollFlickable !== "undefined" && scrollFlickable) {
                scrollFlickable.contentY -= wheel.angleDelta.y
            }
        }
    }
    property bool isLetterHeader: ("itemType" in model) && model.itemType === "letterHeader"
    property bool isBlank: ("itemType" in model) && model.itemType === "blank"
    // Fenestra : lettre de l'en-tête, transmise à la navigation alphabétique au clic
    readonly property string letterText: ("display" in model) ? ("" + model.display) : ""

    // Fenestra : marge intérieure de la tuile, BORNÉE — exactement la même borne que
    // « root.tuilePad » dans MenuRepresentation.qml. Le thème « widgets/viewitem » peut
    // avoir des marges de surlignage énormes qui poussaient l'icône et le libellé vers le
    // bas et forçaient des cellules géantes. En les bornant ici aussi, l'icône et le
    // libellé restent centrés dans la cellule (réduite) et ne sont jamais rognés.
    readonly property int padTop: Math.min(highlightItemSvg.margins.top, Math.round(Kirigami.Units.gridUnit * 0.75))
    readonly property int padLR: Math.min(highlightItemSvg.margins.left, Math.round(Kirigami.Units.gridUnit * 0.75))

    // A folder tile inside the pinned grid (2×2 app mosaic, pinned folder menu).
    // Driven by the grid itself (`pinnedGrid`) instead of a model role, which is
    // more reliable than optional ListModel roles.
    readonly property bool isPinnedFolder: isFolderItem
                                           && item.GridView.view !== null
                                           && item.GridView.view !== undefined
                                           && item.GridView.view.pinnedGrid === true

    Kirigami.Icon {
        id: icon
        visible: !item.isLetterHeader && !item.isBlank && !item.isPinnedFolder
        // Fenestra : icône à « padTop » (au lieu de 2×padTop) pour libérer la hauteur
        // nécessaire au nom sur 2 lignes — la tuile (cellSizeHeight) réserve exactement
        // « padTop + icône + écart + nom + padTop ».
        y: item.showLabel ? item.padTop : undefined
        anchors.horizontalCenter: isIndented ? undefined : parent.horizontalCenter
        anchors.left:             isIndented ? parent.left : undefined
        anchors.leftMargin:       isIndented ? indentOffset : 0
        anchors.verticalCenter: item.showLabel ? undefined : parent.verticalCenter

        width: isIndented ? iconSize * 0.85 : iconSize
        height: width

        animated: false

        source: model.decoration
    }

    // Pinned folder: 2x2 mosaic of member app icons
    Item {
        id: folderMosaic
        visible: item.isPinnedFolder
        y: item.padTop
        width: iconSize
        height: iconSize
        anchors.horizontalCenter: parent.horizontalCenter

        Rectangle {
            anchors.fill: parent
            radius: Kirigami.Units.smallSpacing
            color: root.colorWithAlpha(Kirigami.Theme.highlightColor, 0.15)
            border.width: 1
            border.color: root.colorWithAlpha(Kirigami.Theme.highlightColor, 0.35)
        }

        Grid {
            anchors.centerIn: parent
            columns: 2
            spacing: 2

            Repeater {
                model: {
                    if (!item.isPinnedFolder) return 0;
                    var fd = rootItem.pinnedFoldersData[item.folderIdx];
                    return fd ? Math.min(4, fd.items.length) : 0;
                }
                delegate: Kirigami.Icon {
                    width: (folderMosaic.width - 10) / 2
                    height: width
                    source: {
                        var fd = rootItem.pinnedFoldersData[item.folderIdx];
                        return (fd && fd.items[index]) ? rootItem.iconSourceForId(fd.items[index]) : "";
                    }
                    animated: false
                }
            }
        }

        // Empty folder icon
        Kirigami.Icon {
            visible: {
                var fd = rootItem.pinnedFoldersData[item.folderIdx];
                return fd ? (fd.items || []).length === 0 : false;
            }
            anchors.centerIn: parent
            source: "folder"
            width: folderMosaic.width * 0.7
            height: width
            animated: false
        }
    }

    Rectangle {
        id: letterBand
        visible: item.isLetterHeader
        x: 0
        y: 0
        width: item.GridView.view ? item.GridView.view.width : item.width
        height: item.height
        radius: 0
        color: "transparent" // juste un repère de largeur/position, pas de fond visible
    }

    // Fenestra : l'en-tête de lettre est un index alphabétique cliquable (comme KDE) :
    // il s'éclaire au survol pour montrer qu'on peut cliquer dessus.
    // Le survol est détecté par la MouseArea principale d'ItemGridView (hoverArea),
    // qui expose itemGrid.hoveredLetter. On compare à « item » pour savoir si CETTE
    // tuile est celle sous le curseur.
    readonly property bool isHoveredLetter: (typeof itemGrid !== "undefined") && (itemGrid.hoveredLetter === item)
    Rectangle {
        visible: item.isLetterHeader && item.isHoveredLetter
        anchors.fill: parent
        anchors.margins: 2
        radius: Kirigami.Units.smallSpacing
        color: (Kirigami.Theme.textColor.hslLightness > 0.5 ? "#26ffffff" : "#80ffffff")
        border.width: 1
        border.color: (Kirigami.Theme.textColor.hslLightness > 0.5 ? "#1affffff" : "#14000000")
    }

    Text {
        visible: item.isLetterHeader
        anchors.left: letterBand.left
        anchors.leftMargin: item.GridView.view ? Math.round((item.GridView.view.cellWidth - iconSize) / 2)
                                               : Kirigami.Units.largeSpacing
        anchors.verticalCenter: letterBand.verticalCenter
        text: model.display
        font.family: Kirigami.Theme.defaultFont.family
        font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.1
        font.weight: Font.Normal
        color: item.isHoveredLetter
               ? Kirigami.Theme.textColor
               : (Kirigami.Theme.textColor.hslLightness > 0.5 ? Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.7) : "#4A4A4A")
    }

    PlasmaComponents3.Label {
        id: label

        visible: item.showLabel && !item.isLetterHeader && !item.isBlank

        anchors {
            top: icon.bottom
            topMargin: Kirigami.Units.smallSpacing
            left: parent.left
            leftMargin: isIndented ? (indentOffset + icon.width + Kirigami.Units.smallSpacing) : item.padLR
            right: parent.right
            rightMargin: item.padLR
        }

        horizontalAlignment: isIndented ? Text.AlignLeft : Text.AlignHCenter

        maximumLineCount: item.labels2lines ? 2 : 1
        elide: Text.ElideRight
        wrapMode: Text.WordWrap

        color: isIndented ? root.colorWithAlpha(Kirigami.Theme.textColor, 0.85) : Kirigami.Theme.textColor

        font.pointSize: isIndented
        ? Kirigami.Theme.defaultFont.pointSize * 0.9
        : Kirigami.Theme.defaultFont.pointSize
        // Folder tiles use the localized default name when unrenamed (empty
        // name) so the label follows the system language; apps keep model.display.
        text: isFolderItem ? rootItem.folderDisplayName(model.name) : model.display
        textFormat: Text.PlainText
    }

    // Tag « Nouveauté » sous le nom de l'appli
    Text {
        id: newTag
        visible: item.isNewTag
        anchors.top: label.bottom
        anchors.topMargin: 1
        anchors.horizontalCenter: parent.horizontalCenter
        text: i18n("New")
        color: Kirigami.Theme.highlightColor
        font.pointSize: Kirigami.Theme.defaultFont.pointSize - 1
        font.weight: Font.DemiBold
    }

    // infobulle (étiquette tronquée) : déléguée à l'infobulle partagée au niveau de
    // la fenêtre (tileTipAnchor, cf. MenuRepresentation.qml) — un PC3.ToolTip ancré
    // ici, dans la page défilante, était rendu décalé.
    Item {
        id: toolTip

        property string text: model.display
        readonly property bool containsMouse: toolTipHover.hovered

        anchors.fill: parent
        HoverHandler {
            id: toolTipHover
            onHoveredChanged: {
                item.GridView.view.itemContainsMouseChanged(hovered);
                // Highlight the item under the cursor even if the mouse didn't
                // move (e.g. menu opened with the pointer already over an app).
                if (hovered && root.visible && !item.isLetterHeader && !item.isBlank
                        && item.GridView.view
                        && !(typeof itemGrid !== "undefined" && itemGrid._keyNavRecently())) {
                    item.GridView.view.currentIndex = item.itemIndex;
                }
                if (hovered && root.visible && label.truncated
                        && !item.isLetterHeader && !item.isBlank
                        && !(typeof rootItem !== "undefined" && rootItem.scrolling)
                        && typeof rootItem !== "undefined" && rootItem.showTileTip) {
                    rootItem.showTileTip(toolTip, toolTip.text);
                } else if (typeof rootItem !== "undefined" && rootItem.hideTileTip) {
                    rootItem.hideTileTip(toolTip);
                }
            }
        }
    }

    // Folder edit zone: hover-only tracker (clicks pass through to hoverArea which emits folderEditRequested)
    // Pinned folders have no "+" action: they are managed from the folder popup,
    // so the zone is disabled for them.
    MouseArea {
        id: folderBtnZone
        visible: isFolderItem && !item.isPinnedFolder
        anchors.right: parent.right
        width: Kirigami.Units.gridUnit * 2
        height: parent.height
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        z: 1
    }

    property bool folderEditZoneHovered: isFolderItem && !item.isPinnedFolder && folderBtnZone.containsMouse

    // Visual indicator — non-interactive, top-right corner badge
    Item {
        visible: isFolderItem && !item.isPinnedFolder && folderEditZoneHovered
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: Kirigami.Units.smallSpacing
        anchors.rightMargin: Kirigami.Units.smallSpacing
        width: Kirigami.Units.iconSizes.small + Kirigami.Units.smallSpacing * 2
        height: width
        z: 3

        Rectangle {
            anchors.fill: parent
            radius: Kirigami.Units.smallSpacing
            color: root.colorWithAlpha(Kirigami.Theme.highlightColor, 0.18)
        }

        Kirigami.Icon {
            anchors.centerIn: parent
            source: "list-add"
            width: Kirigami.Units.iconSizes.small
            height: width
            animated: false
        }
    }

    // Ctrl+number keyboard shortcut badge
    Rectangle {
        property int pageRelIdx: rootItem.pinnedItemsPerPage > 0
                                 ? item.itemIndex % rootItem.pinnedItemsPerPage
                                 : item.itemIndex
        visible: !isFolderItem && !isIndented && rootItem.ctrlHeld && pageRelIdx < 9
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: Kirigami.Units.smallSpacing
        anchors.rightMargin: Kirigami.Units.smallSpacing
        width: Kirigami.Units.gridUnit * 1.4
        height: width
        radius: width / 2
        color: Kirigami.Theme.highlightColor
        z: 3

        Behavior on opacity { NumberAnimation { duration: 80 } }

        Text {
            anchors.centerIn: parent
            text: parent.pageRelIdx + 1
            color: "white"
            font.bold: true
            font.pixelSize: parent.width * 0.52
        }
    }

    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Menu && hasActionList) {
                            event.accepted = true;
                            openActionMenu(0, 0);
                        } else if ((event.key === Qt.Key_Enter || event.key === Qt.Key_Return)) {
                            event.accepted = true;

                            if (favoriteId !== "" && typeof rootItem !== "undefined") {
                                rootItem.recordLaunch(favoriteId);
                            }

                            if ("trigger" in GridView.view.model) {
                                GridView.view.model.trigger(index, "", null);
                                // Don't close the menu when opening a folder
                                if (!isFolderItem) {
                                    root.toggle();
                                }
                            }

                            itemGrid.itemActivated(index, "", null);
                        }
                    }
}
