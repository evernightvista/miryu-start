/*
 * Miryu Start — https://github.com/evernightvista/miryu-start
 * Modified by naykkalak (2026) for Miryu Start, a fork of Menu 11 Next by Eisteed.
 * The original notice below is kept. This file is GPL-2.0-or-later;
 * Miryu Start as a whole is distributed under GPL-3.0-or-later.
 */
/***************************************************************************
 *   Copyright (C) 2014 by Weng Xuetian <wengxt@gmail.com>
 *   Copyright (C) 2013-2017 by Eike Hein <hein@kde.org>                   *
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
import QtQuick.Controls 2.15
import QtCore
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PC3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.private.kicker 0.1 as Kicker
import org.kde.kquickcontrolsaddons 2.0

import org.kde.kirigami as Kirigami
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.kitemmodels 1.0 as KItemModels
import org.kde.coreaddons 1.0 as KCoreAddons
import "code/plugins.js" as PluginSystem

PlasmaCore.Dialog {
    id: root

    objectName: "popupWindow"
    flags: Qt.WindowStaysOnTopHint
    // Fenestra : le menu suit toujours l'emplacement du bouton dans la barre
    location: Plasmoid.location
    // Fenestra : floating = 0 demande à PlasmaQuick de supprimer la bordure du
    // côté du panneau (bord du bas pour une barre en bas), comme
    // removeBorderStrategy: AtPanelEdges dans PopupPlasmaWindow. Le menu est
    // donc collé à la barre des tâches sans marge de cadre visible.
    floating: 0
    hideOnWindowDeactivate: true

    // Fenestra : référence EXPLICITE au bouton Démarrer dans la barre. On
    // ne utilise PAS « parent » : PlasmaCore.Dialog (QQuickWindow) n'a pas
    // la même chaîne de parenté QML qu'un QQuickItem, donc « parent.width »
    // pouvait être incorrect ou null → le menu retombait en alignement à gauche.
    // Cette référence est posée par CompactRepresentation au moment de la création.
    //   height: hauteurContenu (avec plancher 200 px), donc la fenêtre est toujours
    //   correctement dimensionnée.
    // NE PAS écrire « height: rootItem.height + ... » à la racine : ça crée une boucle
    // (Dialog.height dépend de mainItem.height, que PlasmaQuick recalcule depuis
    // Dialog.height) → « trying to show an empty dialog » et gel du menu / volet.

    // Fenestra : largeur d'une colonne de tuiles, calquée sur le menu Démarrer de
    // Windows 11 (~95 px). Elle est volontairement PLAFONNÉE : « cellSizeWidth » dérive
    // des marges du thème « widgets/viewitem », qui peuvent être énormes selon le thème
    // installé. Sans plafond, la largeur du menu valait « cellSizeWidth × 6 », soit ici
    // ~1000 px : le menu occupait toute la largeur de l'écran (trop grand, écrasé/en
    // « large et bas »). En bornant la colonne, le menu garde les proportions du vrai
    // Windows 11 quelle que soit la décoration.
    readonly property int largeurColonne: {
        var cible = Math.round(Kirigami.Units.gridUnit * 5.5 * root.echelleMenu);
        var plancher = Math.round(Kirigami.Units.gridUnit * 4 * root.echelleMenu);
        return Math.max(plancher, Math.min(root.cellSizeWidth, cible));
    }

    // Fenestra : 6 colonnes au maximum, comme le menu Démarrer de Windows 11, et jamais plus
    // que ce qui tient réellement à l'écran. Le menu reste ainsi étroit (et donc centrable),
    // aucune colonne n'est rognée, et il n'est plus « écrasé » en largeur.
    readonly property int colonnesAuto: {
        var tiennent = Math.floor((kicker.screenGeometry.width - Kirigami.Units.gridUnit * 4) / largeurColonne);
        return Math.max(3, Math.min(6, tiennent));
    }

    property int iconSize: {
        var base;
        switch (Plasmoid.configuration.appsIconSize) {
        case 0:
            base = Kirigami.Units.iconSizes.smallMedium; break;
        case 1:
            base = Kirigami.Units.iconSizes.medium; break;
        case 2:
            base = Kirigami.Units.iconSizes.large; break;
        case 3:
            base = Kirigami.Units.iconSizes.huge; break;
        default:
            base = 64;
        }
        return Math.max(16, Math.round(base * root.echelleMenu));
    }

    property int docsIconSize: {
        var base;
        switch (Plasmoid.configuration.docsIconSize) {
        case 0:
            base = Kirigami.Units.iconSizes.smallMedium; break;
        case 1:
            base = Kirigami.Units.iconSizes.medium; break;
        case 2:
            base = Kirigami.Units.iconSizes.large; break;
        case 3:
            base = Kirigami.Units.iconSizes.huge; break;
        default:
            base = Kirigami.Units.iconSizes.medium;
        }
        return Math.max(16, Math.round(base * root.echelleMenu));
    }

    // Fenestra : marge intérieure d'une tuile, BORNÉE. Le thème « widgets/viewitem »
    // peut définir des marges de surlignage très grandes (~19 px) ; la cellule valait
    // alors « iconSize + 2×grille + 2×(marges) » ≈ 145 px, ce qui gonflait toutes les
    // tuiles (et donc le menu). On les borne à ~¾ de gridUnit. Si le thème a des marges
    // plus petites (Breeze), c'est la valeur du thème qui est gardée : rien ne change.
    readonly property int tuilePad: Math.min(highlightItemSvg.margins.top, Math.round(Kirigami.Units.gridUnit * 0.75 * root.echelleMenu))

    // Fenestra : hauteur d'UNE ligne de libellé, mesurée sur la police réelle du thème.
    // FontMetrics est déclaré en PROPRIÉTÉ, pas en enfant du dialogue : la propriété par
    // défaut de PlasmaCore.Dialog n'accepte que des « QQuickItem », un enfant non-Item
    // faisait échouer le chargement de tout MenuRepresentation
    // (« Cannot assign object of type "FontMetrics" to property of type "QQuickItem*" »,
    // puis « Type MenuRepresentation unavailable » et menu qui ne s'ouvre plus).
    readonly property QtObject labelFontMetrics: FontMetrics {
        font {
            family: Kirigami.Theme.defaultFont.family
            pointSize: Kirigami.Theme.defaultFont.pointSize * root.echelleMenu
            weight: Kirigami.Theme.defaultFont.weight
        }
    }
    readonly property int labelLineHeight: Math.max(1, Math.ceil(labelFontMetrics.lineSpacing))

    // Fenestra : hauteur d'une tuile. Elle doit contenir l'icône ET le nom (1 ou 2 lignes
    // selon la configuration) : c'est ce qui garantit que le libellé ne dépasse plus jamais
    // le surlignement (bordure de la cellule). Avant, on réservait la place d'UNE seule
    // ligne : le nom sur 2 lignes (« Dolphin 文件管理器 ») sortait par le bas de la tuile.
    // marge haute + icône + écart icône/nom + nom + marge basse.
    property int cellSizeHeight: 2 * tuilePad + iconSize + Math.round(Kirigami.Units.smallSpacing * root.echelleMenu)
                                 + (Plasmoid.configuration.labels2lines ? 2 : 1) * labelLineHeight
    property int cellSizeWidth: cellSizeHeight + Kirigami.Units.gridUnit

    // Fenestra : écran utile de l'applet (zone hors barres / panneaux), exposé au pied
    // (Footer) pour que la fenêtre « Compte » reste TOUJOURS entièrement visible.
    // Source : « kicker.availableScreenRect » / « kicker.screenGeometry », exactement
    // comme popupPosition() ci-dessous. « plasmoid.* » ne s'y résout pas, ce qui rendait
    // le bornage inopérant : x valait « centre du bouton − largeur/2 » et la fenêtre
    // Compte sortait par le bord gauche de l'écran (tronquée, cf. 图一).
    readonly property rect ecranUtile: {
        var g = kicker.screenGeometry;
        var a = kicker.availableScreenRect;
        if (!g && !a) return Qt.rect(0, 0, 0, 0);
        var gx = g ? g.x : 0, gy = g ? g.y : 0;
        var gw = g ? g.width : 0, gh = g ? g.height : 0;
        var ax = a ? a.x : 0, ay = a ? a.y : 0;
        var aw = a ? a.width : 0, ah = a ? a.height : 0;
        return Qt.rect(gx + ax, gy + ay, aw > 0 ? aw : gw, ah > 0 ? ah : gh);
    }

    property bool searching: (searchField.text != "")

    // Fenestra : facteur d'échelle global du menu en basse résolution.
    // En dessous d'une taille de référence (1600×900), tout le contenu (icônes,
    // tuiles, colonnes, espacements) est réduit PROPORTIONNELLEMENT, comme avant
    // les modifications de mise en page. Le menu reste ainsi entier et lisible
    // sur les petits écrans plutôt que d'être rogné ou éparpillé en peu de colonnes.
    readonly property real echelleMenu: {
        var ecranW = kicker.screenGeometry.width;
        var ecranH = kicker.availableScreenRect.height;
        var refW = 1600;
        var refH = 900;
        var facteurW = (ecranW > 0) ? Math.min(1.0, ecranW / refW) : 1.0;
        var facteurH = (ecranH > 0) ? Math.min(1.0, ecranH / refH) : 1.0;
        return Math.max(0.65, Math.min(facteurW, facteurH));
    }

    onSearchingChanged: {
        if (searching) {
            view.currentIndex = 1;
        } else {
            view.currentIndex = 0;
            kicker.searchRunnerFilter = "all";
        }
    }
    onVisibleChanged: {
        if (visible) {
            // Fenestra : largeur de la fenêtre donnée à l'ouverture — PlasmaCore.Dialog
            // inclut les marges du cadre dans « width » (PlasmaQuick::Dialog). On fixe
            // explicitement Dialog.width = largeur du contenu + marges du cadre pour
            // garantir que les coordonnées globales des Items sont correctes dès le
            // premier affichage. Sans ça, le ToolTip de PlasmaComponents3 se positionne
            // sur une géométrie de fenêtre erronée (marges = 0 avant chargement asynchrone
            // du FrameSvg du thème) et apparaît décalé. C'est une AFFECTATION UNIQUE,
            // pas une liaison : aucun risque de boucle.
            // Normalisation à 0 si margins.left/right sont undefined (évite width = NaN).
            var ml = isFinite(margins.left) ? margins.left : 0;
            var mr = isFinite(margins.right) ? margins.right : 0;
            // On utilise largeurVoulue (la largeur de contenu voulue, fixe) et NON
            // rootItem.width : PlasmaQuick::Dialog recalcule mainItem.width depuis
            // Dialog.width, donc rootItem.width peut être temporairement erroné et
            // créer une boucle / une largeur instable. La largeur de la fenêtre doit
            // dépendre de la largeur de contenu voulue, pas l'inverse.
            width = Math.round(rootItem.largeurVoulue + ml + mr);
            // Fenestra : re-correction de la largeur après chargement des marges du
            // cadre (une seule fois). Stabilise la géométrie pour les ToolTip.
            ajustementLargeur.restart();
            // Fenestra : si le volet est prévu (option "mémoriser"), on l'ouvre
            // SYNCHRONEMENT AVANT de calculer la position du menu. Comme ça panel.width
            // est correct (pas zéro), popupPosition(totalW = menu + volet) donne la
            // bonne position dès le premier glissement — le menu et le volet
            // apparaissent EN MÊME TEMPS, animations synchronisées.
            voletPrevu = Plasmoid.configuration.kdeConnectMemoriser && Plasmoid.configuration.kdeConnectPanelOn;
            if (voletPrevu && !kdeConnectPanel.visible) {
                Plasmoid.configuration.kdeConnectPanelOn = true;
                kdeConnectPanel.open();
            }
            var pos = popupPosition(width, height);
            x = pos.x;
            y = pos.y;
            // Fenestra : les dossiers épinglés doivent être chargés AVANT le premier
            // affichage de la grille. Sinon la tuile-dossier n'existe pas encore au
            // premier rendu, puis loadFolders() (30 ms plus tard) reconstruit le
            // modèle et toute la liste « saute » à l'ouverture.
            rootItem.loadFolders();
            rootItem.loadAllAppsFolders();
            rootItem.loadPinnedOrder();
            // Un lanceur désépinglé depuis miryu-search doit avoir quitté son
            // dossier AVANT le premier rendu de la grille : sinon il resterait
            // affiché jusqu'à ce que l'on ouvre le dossier. Les favoris étant
            // déjà à jour dans KActivities à ce stade, la purge est fiable.
            rootItem.epurerDossiersEpingles();
            reset();
            // Fenestra : chargements après l'affichage (le menu se dessine d'abord)
            chargementsOuverture.restart();
        } else {
            // Fenestra : fermeture du menu — on réinitialise voletPrevu. Sinon
            // la valeur de l'ouverture précédente reste en mémoire et pollue
            // la position du menu à l'ouverture suivante.
            voletPrevu = false;
            view.currentIndex = 0;
            rootItem.hideTileTip();        // ferme l'infobulle de tuile avec le menu
        }
    }

    onHeightChanged: {
        if (visible) {
            var pos = popupPosition(width, height);
            x = pos.x;
            y = pos.y;
        }
    }

    onWidthChanged: {
        if (visible) {
            var pos = popupPosition(width, height);
            x = pos.x;
            y = pos.y;
        }
    }

    // Fenestra : PlasmaCore.Dialog.margins est une propriété CONSTANT (pas de signal
    // marginsChanged). Au premier affichage, les sous-propriétés (left/right) peuvent
    // être undefined (chargement asynchrone du FrameSvg du thème). On applique donc la
    // largeur corrigée UNE SEULE FOIS après un court délai (ajustementLargeur, défini
    // dans mainItem), le temps que les marges réelles soient chargées. On n'utilise PAS
    // de Binding on width : une liaison continue réévalue la largeur à chaque changement
    // de marge, ce qui fait « vibrer » la géométrie de la fenêtre et décale les ToolTip
    // de PlasmaComponents3 (ils se basent sur les coordonnées globales au moment de
    // l'affichage). Une mise à jour unique stabilise la fenêtre et garantit des tooltips
    // bien positionnés.

    function toggle() {
        root.visible = !root.visible;
    }

    // Fenestra : chargements après l'affichage : appelés juste après l'ouverture.
    // Les données légères (dossiers épinglés, compteurs de lancement) sont relues
    // à chaque ouverture — c'est peu coûteux. En revanche la lecture des dates des
    // documents récents lance un sous-processus python/sqlite : on ne la relance
    // donc qu'au plus une fois par minute. Le préchargement au démarrage (3 s)
    // sert de base aux ouvertures suivantes, ce qui rend l'ouverture instantanée.
    property double derniereLectureDocs: 0
    readonly property int intervalLectureDocs: 60000
    function chargerApresOuverture(force) {
        if (!root.visible && !force) return;
        rootItem.loadFolders();
        rootItem.loadAllAppsFolders();
        rootItem.loadPinnedOrder();
        // Prise en compte d'un retrait de favori survenu ailleurs depuis la
        // dernière ouverture (miryu-search, réglages système) : un dossier ne
        // montre jamais un lanceur qui n'est plus un favori Kicker, même si la
        // configuration du plasmoïde n'a pas encore été relue.
        // À l'ouverture le modèle peut ne pas être prêt : la purge est retentée.
        rootItem.epurerDossiersEpingles();
        rootItem.buildPinnedCombo();
        // Filet de sécurité : les favoris sont chargés de façon asynchrone (KAStats).
        // Si la toute première construction a eu lieu avant leur arrivée, la grille
        // épinglée n'affiche que les dossiers. On reconstruit dès que l'écart apparaît.
        if (globalFavorites && globalFavorites.rowCount() !== rootItem.pinnedBuiltRows) {
            rootItem.buildPinnedCombo();
        }
        rootItem.loadLaunchCounts();
        var maintenant = Date.now();
        if (force || maintenant - derniereLectureDocs >= intervalLectureDocs) {
            derniereLectureDocs = maintenant;
            try {
                rootItem.refreshDocDates();
            } catch (e) {
                console.warn("fenestra-menu11 : page recommandations (dates) :", e);
            }
        }
        if (Plasmoid.configuration.allAppsViewMode === 2) {
            ensureCategoryModel();
        }
    }

    function reset() {
        searchDebounce.stop();
        rootItem.hideTileTip();            // infobulle de tuile éventuellement restée visible
        rootItem.pluginResults = [];
        searchField.text = "";
        searchField.focus = true;
        view.currentIndex = 0;
        mainFlick.contentY = 0;
        globalFavoritesGrid.currentIndex = -1;
        documentsGrid.currentIndex = -1;
        allAppsGrid.currentIndex = -1;
        rootItem.pinnedCurrentPage = 0;
        kicker.searchRunnerFilter = "all";
        folderContentPopup.visible = false;
        createFolderOverlay.visible = false;
        allAppsFolderPopup.visible = false;
        createAllAppsFolderOverlay.visible = false;
        viewModePopup.visible = false;
        categoryFlyout.visible = false;
        letterPicker.visible = false;
    }

    // Fenestra : groupe menu + volet centré : largeur du volet + écart, quand il est (ou va être) ouvert
    property bool voletPrevu: false
    function largeurVolet() {
        if (!voletPrevu) return 0;
        var pm = kdeConnectPanel.margins || { left: 0, right: 0 };
        var w = kdeConnectPanel.width > 0 ? kdeConnectPanel.width
              : kdeConnectPanel.mainItem.width + (pm.left || 0) + (pm.right || 0);
        return w + Kirigami.Units.smallSpacing * 2;
    }

    // Fenestra : glissement du menu : durée du déplacement du menu (ms)
    property int dureeGlissement: 250   // Fenestra : glissement du menu
    // Fenestra : délais du groupe : départ du volet après le début du glissement / retour du menu après le début de l'effacement
    property int delaiOuvertureVolet: 250   // Fenestra : délais du groupe
    property int delaiFermetureVolet: 200   // Fenestra : délais du groupe
    function glisserMenuVers(nx) {
        glissementMenu.stop();
        glissementMenu.from = x;
        glissementMenu.to = nx;
        glissementMenu.duration = dureeGlissement;
        glissementMenu.start();
    }
    // Fenestra : ordre du recentrage : à l'ouverture, le menu se décale d'abord, puis le volet apparaît
    function basculerVolet() {
        if (kdeConnectPanel.visible) { kdeConnectPanel.toggle(); return; }
        attenteRecentrage.stop();
        // Fenestra : ouverture SYNCHRONE — pas de Timer intermédiaire. On met
        // voletPrevu, on ouvre le volet (visible = true tout de suite) puis
        // on recalcule la position du menu. Les deux animations partent en
        // parallèle dès ce moment : glissement du menu et ouverture du volet.
        voletPrevu = true;
        if (!kdeConnectPanel.visible) {
            // Fenestra : on garde la préférence synchronisée — toggle() le fait,
            // mais la branche "ouverture directe" de basculerVolet ne le faisait pas.
            Plasmoid.configuration.kdeConnectPanelOn = true;
            kdeConnectPanel.open();
        }
        // Le volet est ouvert, sa width est connue → popupPosition donne la bonne pos
        var pos = popupPosition(width, height);
        y = pos.y;
        glisserMenuVers(pos.x);
        // Plus besoin d'apparitionVolet — tout est déjà lancé en parallèle.
    }
    function recentrerMenu() {
        if (!visible || kdeConnectPanel.visible) return;
        voletPrevu = false;
        var pos = popupPosition(width, height);
        y = pos.y;
        glisserMenuVers(pos.x);
    }

    function popupPosition(width, height) {
        var screenAvail = kicker.availableScreenRect;
        var screenGeom = kicker.screenGeometry;
        var screen = Qt.rect(screenAvail.x + screenGeom.x, screenAvail.y + screenGeom.y, screenAvail.width, screenAvail.height);

        var offset = Kirigami.Units.smallSpacing;
        var totalW = width + root.largeurVolet();   // Fenestra : menu + volet KDE Connect centrés ensemble
        // Fenestra : hauteur de FENÊTRE du menu, marges du cadre INCLUSES. « height » d'un
        // PlasmaCore.Dialog est déjà cette hauteur totale (PlasmaQuick::Dialog : « total
        // height of the dialog, including margins ») : la retrancher suffit, inutile d'y
        // rajouter les marges du cadre (les compter deux fois remontait le menu trop haut
        // ou, selon le thème / le zoom, le laissait déborder sur la barre des tâches).
        // Au tout premier affichage, « height » peut ne pas avoir encore suivi le
        // redimensionnement : on calcule alors la hauteur depuis le contenu (rootItem.height)
        // + marges du cadre et on garde la plus grande, pour rester collé à la barre quelle
        // que soit la résolution ou l'échelle d'écran.
        var m = root.margins;
        var margeGauche = (m && isFinite(m.left)) ? m.left : 0;
        var margeDroite = (m && isFinite(m.right)) ? m.right : 0;
        var margeHaut = (m && isFinite(m.top)) ? m.top : 0;
        var margeBas = (m && isFinite(m.bottom)) ? m.bottom : 0;
        // Fenestra : hauteur de FENÊTRE du menu. On utilise EN PRIORITÉ le paramètre
        // « height » (Dialog.height réel, marges du cadre INCLUSES) : cela garantit
        // que y = écran - hauteurRéelle, donc que le bas de la fenêtre est exactement
        // collé à la barre des tâches, quelle que soit la résolution. On ne retombe
        // sur le calcul depuis hauteurContenu + marges que si « height » n'est pas
        // encore valide (premier affichage, avant que PlasmaQuick n'ait appliqué la
        // taille). Auparavant, utiliser hauteurContenu (qui soustrait espaceHaut pour
        // les coins arrondis) donnait une hauteurFenetre inférieure à la hauteur réelle
        // de la fenêtre : le menu était alors décollé de la barre des tâches.
        var hauteurFenetre = (isFinite(height) && height > 0)
            ? height
            : (rootItem.hauteurContenu + margeHaut);
        // Aucune marge de sécurité : le menu est collé à la barre des tâches comme le
        // menu Démarrer de Windows 11 (hauteurContenu limite déjà la hauteur de contenu
        // pour que la fenêtre tienne dans l'écran utile).
        // Fenestra : floating = 0 demande à PlasmaQuick de supprimer la bordure du côté
        // du panneau (bas pour BottomEdge). La bordure basse n'est donc PAS dessinée,
        // mais margins.bottom peut toujours renvoyer la valeur du Svg (non nulle).
        // On ne doit PAS ajouter margeBas à y : cela ferait descendre la fenêtre de
        // l'épaisseur du cadre et la chevaucherait sur la barre des tâches.
        // y = écran - hauteurFenetre place le bas de la fenêtre exactement au ras de
        // la barre (bordure basse déjà supprimée par floating = 0).
        var securite = 0;

        // Fall back to bottom-left of screen area when the applet is on the desktop or floating.
        var x = screen.x + offset;
        var y = screen.y + screen.height - hauteurFenetre - securite;
        var appletTopLeft = parent.mapToGlobal(0, 0);
        function borne(minV, maxV, v) { return Math.max(minV, Math.min(v, maxV)); }

        // Fenestra : le menu suit l'emplacement du bouton dans la barre. Sa position
        // s'aligne sur le centre du bouton puis reste dans l'écran (bornée) :
        // bouton à gauche -> menu à gauche, bouton centré -> menu centré.
        // Il est collé à la barre (aucun espace) comme le menu Démarrer de Windows 11.
        if (Plasmoid.location === PlasmaCore.Types.BottomEdge) {
            var centreBoutonX = appletTopLeft.x + parent.width / 2;
            x = borne(screen.x + offset,
                      screen.x + screen.width - totalW - offset,
                      centreBoutonX - totalW / 2);
            y = screen.y + screen.height - hauteurFenetre - securite;
        } else if (Plasmoid.location === PlasmaCore.Types.TopEdge) {
            var centreBoutonHautX = appletTopLeft.x + parent.width / 2;
            x = borne(screen.x + offset,
                      screen.x + screen.width - totalW - offset,
                      centreBoutonHautX - totalW / 2);
            y = screen.y;
        } else if (Plasmoid.location === PlasmaCore.Types.LeftEdge) {
            var centreBoutonY = appletTopLeft.y + parent.height / 2;
            x = appletTopLeft.x + parent.width + margeDroite + offset;
            y = borne(screen.y + offset,
                      screen.y + screen.height - hauteurFenetre - securite,
                      centreBoutonY - hauteurFenetre / 2);
        } else if (Plasmoid.location === PlasmaCore.Types.RightEdge) {
            var centreBoutonDroitY = appletTopLeft.y + parent.height / 2;
            x = appletTopLeft.x - margeGauche - offset - width;
            y = borne(screen.y + offset,
                      screen.y + screen.height - hauteurFenetre - securite,
                      centreBoutonDroitY - hauteurFenetre / 2);
        }
        return Qt.point(x, y);
    }

    function colorWithAlpha(color: color, alpha: real): color {
        return Qt.rgba(color.r, color.g, color.b, alpha);
    }

    mainItem: FocusScope {
        id: rootItem
        // Fenestra : chargements après l'affichage : minuteur des chargements
        Timer { id: chargementsOuverture; interval: 30; onTriggered: root.chargerApresOuverture() }
        // Fenestra : re-correction de la largeur après chargement des marges du cadre
        // (une seule fois). Stabilise la géométrie pour les ToolTip (pas de Binding
        // on width continu qui ferait vibrer la fenêtre).
        Timer {
            id: ajustementLargeur
            interval: 30
            repeat: false
            onTriggered: {
                if (!root.visible) return;
                var ml = isFinite(root.margins.left) ? root.margins.left : 0;
                var mr = isFinite(root.margins.right) ? root.margins.right : 0;
                var w = Math.round(rootItem.largeurVoulue + ml + mr);
                if (w !== root.width) {
                    root.width = w;
                }
            }
        }
        // Fenestra : groupe menu + volet centré : le volet s'ouvre ou se ferme -> le menu se recentre
        Connections {
            target: kdeConnectPanel
            function onVisibleChanged() {
                if (!root.visible) return;
                if (kdeConnectPanel.visible) {
                    attenteRecentrage.stop();
                    if (!root.voletPrevu) {
                        root.voletPrevu = true;
                        var pos = root.popupPosition(root.width, root.height);
                        root.x = pos.x;
                        root.y = pos.y;
                    }
                } else {
                    attenteRecentrage.restart();   // Fenestra : ordre du recentrage : le volet s'efface d'abord
                }
            }
        }
        Timer { id: attenteRecentrage; interval: root.delaiFermetureVolet; onTriggered: root.recentrerMenu() }
        NumberAnimation { id: glissementMenu; target: root; property: "x"; easing.type: Easing.OutCubic }   // Fenestra : glissement du menu
        Timer { id: apparitionVolet; interval: 0; onTriggered: if (root.visible && !kdeConnectPanel.visible) kdeConnectPanel.toggle() }
        // Fenestra : préchargement au démarrage : dates des recommandations prêtes avant la 1re ouverture
        Timer { id: prechargement; interval: 3000; onTriggered: root.chargerApresOuverture(true) }


        property int widthComputed: root.largeurColonne * root.colonnesAuto + Kirigami.Units.gridUnit * 2

        property int pinnedCurrentPage: 0
        property int pinnedItemsPerPage: root.colonnesAuto * Plasmoid.configuration.numberRows
        property bool ctrlHeld: false
        property bool pinnedCollapsed: false
        property int pinnedCollapsedRows: 2   // rangées visibles quand replié (façon Windows 11)
        // horodatage (ms) de la dernière touche de navigation dans une grille, partagé par toutes les grilles
        property double lastNavKeyTime: 0
        function keyNavRecently() { return Date.now() - lastNavKeyTime < 400; }
        // bord gauche commun de toutes les rubriques (= bord de la 1re icône épinglée, icône centrée dans sa cellule)
        property int sectionInset: Math.max(0, Math.round((globalFavoritesGrid.cellWidth - root.iconSize) / 2))
        // marge interne gauche des lignes de recommandations / de la liste « Tout » (icône décalée dans sa ligne)
        property int listIconPad: Math.round(Kirigami.Units.gridUnit / 2)

        // Bouton d'en-tête de section : sans cadre, surlignement blanc 50 % au survol
        // (même fond que le cadre des boutons d'applis de la barre des tâches)
        component SectionButton: Item {
            id: sectionBtn
            property string text: ""
            property string iconName: ""
            property bool flat: false          // gardés pour compatibilité avec AToolButton
            property int buttonHeight: 25
            property bool iconLeft: false      // icône avant le texte
            signal clicked()

            implicitWidth: btnRow.implicitWidth + Kirigami.Units.largeSpacing * 2
            implicitHeight: buttonHeight
            Accessible.role: Accessible.Button
            Accessible.name: text

            Rectangle {
                anchors.fill: parent
                radius: 5
                color: (Kirigami.Theme.textColor.hslLightness > 0.5 ? "#26ffffff" : "#80ffffff")
                border.width: 1                 // même bordure que les autres surlignements
                border.color: (Kirigami.Theme.textColor.hslLightness > 0.5 ? "#1affffff" : "#14000000")
                opacity: btnMouse.containsMouse ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 100 } }
            }

            Row {
                id: btnRow
                anchors.centerIn: parent
                spacing: Kirigami.Units.smallSpacing
                layoutDirection: sectionBtn.iconLeft ? Qt.RightToLeft : Qt.LeftToRight

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: sectionBtn.text
                    color: Kirigami.Theme.textColor
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize
                }

                Kirigami.Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: sectionBtn.iconName !== ""
                    source: sectionBtn.iconName
                    width: Kirigami.Units.iconSizes.small
                    height: width
                    animated: false
                }
            }

            MouseArea {
                id: btnMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: sectionBtn.clicked()
            }
        }
        property int pinnedTotalPages: globalFavoritesGrid.count > 0
            ? Math.max(1, Math.ceil(globalFavoritesGrid.count / pinnedItemsPerPage))
            : 1

        onPinnedCurrentPageChanged: {
            globalFavoritesGrid.positionAtIndex(pinnedCurrentPage * pinnedItemsPerPage);
        }

        onPinnedTotalPagesChanged: {
            if (pinnedCurrentPage >= pinnedTotalPages) {
                pinnedCurrentPage = Math.max(0, pinnedTotalPages - 1);
            }
        }

        // Fenestra : marges latérales réduites : 8 px de marge de chaque côté (18 à l'origine)
        readonly property int margeCote: 8
        // Fenestra : la largeur de la fenêtre suit exactement la largeur du contenu
        // (colonnes + marge de la grille). Plus de décalage entre la fenêtre et la grille,
        // donc plus de colonne rognée à droite ; et le menu reste plus étroit, proche de
        // Windows 11, au lieu des 697 px fixes d'origine.
        readonly property int largeurVoulue: widthComputed + 2 * margeCote
        width: largeurVoulue
        // Fenestra : hauteur de la zone défilante. On remplit toute la hauteur DISPONIBLE
        // (celle qui s'arrête au-dessus de la barre des tâches), comme le menu Démarrer de
        // Windows 11 qui descend jusqu'à la barre : le menu n'est donc plus « écrasé »
        // (large et bas). On plafonne à ~34 gridUnit (~740 px, la hauteur du vrai menu
        // Windows 11) pour ne pas coller au bord haut sur les grands écrans.
        readonly property real viewWanted: {
            // Fenestra : hauteur de la zone défilante, TOUJOURS bornée par l'écran utile.
            // On retranche l'en-tête (view.y) et le pied (footer.height) de la hauteur
            // d'écran disponible : le menu entier (en-tête + page + pied) tient donc
            // forcément à l'écran, même en basse résolution (ex. 1200x800). Le plafond
            // « menu Démarrer » (34 gridUnit) garde les proportions de Windows 11 sur les
            // grands écrans. Le plancher ne dépasse JAMAIS l'espace réellement libre,
            // sinon le haut du menu serait rogné par PlasmaQuick (barre de recherche coupée).
            // Aucune marge de sécurité soustraite : le menu est collé à la barre des tâches
            // comme le menu Démarrer de Windows 11 (cf. popupPosition / hauteurContenu).
            var ecran = kicker.availableScreenRect.height;
            var plafond = Kirigami.Units.gridUnit * 34;
            if (!isFinite(ecran) || ecran <= 0)
                return plafond;
            var dispo = ecran - view.y - footer.height;
            if (dispo <= 0)
                return Math.max(0, ecran - view.y - footer.height);
            return Math.min(dispo, Math.max(Kirigami.Units.gridUnit * 8, Math.min(plafond, dispo)));
        }

        // Fenestra : hauteur du contenu (haut de page + page souhaitée + pied). C'est une
        // propriété en LECTURE SEULE, volontairement distincte de « height » : le dialogue
        // réécrit « height » d'après la taille de la fenêtre, et si les indices Layout
        // pointaient sur « height », chaque réécriture relançait un redimensionnement en
        // boucle (fenêtre qui rétrécit jusqu'à zéro). Le plancher (200 px) garantit une
        // taille toujours positive, la condition vérifiée avant l'affichage.
        readonly property int hauteurContenu: {
            var h = view.y + rootItem.viewWanted + footer.height;
            // Fenestra : filet de sécurité : le menu ne doit jamais dépasser l'écran utile,
            // sinon PlasmaQuick le rogne par le haut (barre de recherche / en-tête coupés).
            // floating = 0 supprime la bordure BASSE du cadre (celle du côté de la barre
            // des tâches) : on ne réserve donc que la marge HAUTE (mt) pour dimensionner
            // le contenu. La marge basse (mb) n'est pas dessinée, inutile de lui réserver
            // de la place (ça laisserait un écart entre le menu et la barre).
            var ecran = kicker.availableScreenRect.height;
            if (isFinite(ecran) && ecran > 0) {
                var m = root.margins;
                var mt = (m && isFinite(m.top)) ? m.top : 0;
                var marginsConnues = mt > 0;
                // Si les marges du cadre ne sont pas encore chargées (premier affichage),
                // on utilise une estimation prudente pour la marge haute uniquement (la
                // bordure basse est supprimée par floating = 0).
                var margeCadre = marginsConnues ? mt : Kirigami.Units.gridUnit;
                // Fenestra : laisse un espace entre le HAUT de la fenêtre et le bord
                // supérieur de l'écran. Sans ça, en basse résolution, la fenêtre du menu
                // touche exactement le haut de l'écran et KWin rogne les coins arrondis
                // du cadre (les pixels anti-crénelage dépassent de l'écran). L'espace
                // réservé vaut la marge haute du cadre + un petit espace, ce qui laisse
                // apparaître le coin arrondi en entier.
                var espaceHaut = (marginsConnues ? mt : Kirigami.Units.gridUnit) + Kirigami.Units.smallSpacing;
                h = Math.min(h, ecran - margeCadre - espaceHaut);
            }
            return isFinite(h) && h >= 1 ? Math.round(h) : 200;
        }
        height: hauteurContenu

        Layout.minimumWidth: largeurVoulue
        Layout.maximumWidth: largeurVoulue
        Layout.minimumHeight: hauteurContenu
        Layout.maximumHeight: hauteurContenu

        focus: true
        onFocusChanged: {
            // Don't steal focus back to the search box when a modal overlay
            // (folder content, etc.) is open.
            if (!folderContentPopup.visible
                && !allAppsFolderPopup.visible && !folderAppPickerPopup.visible
                && !createFolderOverlay.visible) {
                searchField.focus = true;
            }
        }

        KCoreAddons.KUser { id: menuUser }

        property string timeGreeting: {
            var h = new Date().getHours();
            if (h < 12) return i18n("Good morning");
            if (h < 18) return i18n("Good afternoon");
            return i18n("Good evening");
        }

        // ── Pinned Folders ──────────────────────────────────────────────────
        property var pinnedFoldersData: []
        // Fenestra : contenu brut déjà lu : on ne reconstruit que s'il a changé
        // (chaque ouverture relisait la config et recréait les tableaux, ce qui
        // déclenchait des reconstructions de modèles inutiles à l'ouverture).
        property string _foldersRaw: ""

        function loadFolders() {
            var raw = Plasmoid.configuration.pinnedFolders || "";
            if (raw === _foldersRaw) return;
            _foldersRaw = raw;
            if (raw.length === 0) { pinnedFoldersData = []; return; }
            try { pinnedFoldersData = JSON.parse(raw); } catch(e) { pinnedFoldersData = []; }
        }

        function saveFolders() {
            _foldersRaw = JSON.stringify(pinnedFoldersData);
            Plasmoid.configuration.pinnedFolders = _foldersRaw;
        }

        // ── Shared order of pinned entries (apps + folder tiles) ────────────
        // The Kicker favorites model only orders apps, and pinning always
        // appended folder tiles after them, so a folder could never be moved
        // (and no app could be placed after the last folder). This list is the
        // single source of truth for the pinned grid order; it interleaves
        // "a:<favoriteId>" app keys with "f:<folder identity>" folder keys.
        property var pinnedOrderData: []
        property string _pinnedOrderRaw: ""

        function pinnedAppKey(favId) {
            return "a:" + favId;
        }

        function pinnedFolderKey(folder) {
            if (!folder) return "";
            if (folder.createdAt) return "f:" + folder.createdAt;
            return "f:name:" + (folder.name || "");
        }

        function loadPinnedOrder() {
            var raw = Plasmoid.configuration.pinnedOrder || "";
            if (raw === _pinnedOrderRaw) return;
            _pinnedOrderRaw = raw;
            if (raw.length === 0) { pinnedOrderData = []; return; }
            try {
                var parsed = JSON.parse(raw);
                pinnedOrderData = (parsed instanceof Array) ? parsed : [];
            } catch(e) { pinnedOrderData = []; }
        }

        function savePinnedOrder() {
            _pinnedOrderRaw = JSON.stringify(pinnedOrderData);
            Plasmoid.configuration.pinnedOrder = _pinnedOrderRaw;
        }

        onPinnedFoldersDataChanged: {
            if (typeof pinnedFavoritesFiltered !== "undefined") {
                pinnedFavoritesFiltered.invalidate();
            }
            if (typeof pinnedComboModel !== "undefined") {
                buildPinnedCombo();
            }
        }

        // Create a pinned folder from two apps (drag-app-onto-app gesture)
        function createPinnedFolderFromApps(appId1, appId2) {
            if (!appId1 || !appId2 || appId1 === appId2) return;
            var folders = pinnedFoldersData.slice();
            folders.push({
                name: i18n("Folder"),
                items: [appId1, appId2],
                createdAt: Date.now()
            });
            pinnedFoldersData = folders;
            saveFolders();
        }

        // ── All Apps Folders ────────────────────────────────────────────────
        property var allAppsFoldersData: []
        property string _allAppsFoldersRaw: ""

        function loadAllAppsFolders() {
            var raw = Plasmoid.configuration.allAppsFolders || "";
            if (raw === _allAppsFoldersRaw) return;
            _allAppsFoldersRaw = raw;
            if (raw.length === 0) { allAppsFoldersData = []; return; }
            try { allAppsFoldersData = JSON.parse(raw); } catch(e) { allAppsFoldersData = []; }
        }

        function saveAllAppsFolders() {
            _allAppsFoldersRaw = JSON.stringify(allAppsFoldersData);
            Plasmoid.configuration.allAppsFolders = _allAppsFoldersRaw;
        }

        function launchFolderApp(desktopId) {
            // Search the source model by the favoriteId role (Qt.UserRole + 3),
            // which is exactly what is stored in pinnedFoldersData items.
            var count = globalFavorites.rowCount();
            for (var i = 0; i < count; i++) {
                var idx = globalFavorites.index(i, 0);
                var favId = globalFavorites.data(idx, Qt.UserRole + 3);
                if (favId === desktopId) {
                    rootItem.recordLaunch(desktopId);
                    globalFavorites.trigger(i, "", null);
                    break;
                }
            }
            // Always close the start menu after launching (same as pinned apps)
            root.toggle();
        }

        function displayNameForId(id) {
            if (id.startsWith("preferred://")) {
                var s = id.slice(12);
                return s.charAt(0).toUpperCase() + s.slice(1);
            }
            var base = id.replace(/\.desktop$/, "");
            var name = base.split(".").pop();
            return name.split("-").map(function(w) {
                return w.length > 0 ? w.charAt(0).toUpperCase() + w.slice(1) : "";
            }).join(" ");
        }

        function iconForId(id) {
            return id.startsWith("preferred://") ? "emblem-default" : id.replace(/\.desktop$/, "");
        }

        // Read the Icon= field from a .desktop file (file:// URL) and return
        // the icon name. The model's decoration role returns a QIcon which
        // cannot be reliably passed through JS to Kirigami.Icon.source, so we
        // resolve the real icon name from the .desktop file instead.
        function iconNameFromDesktopFile(desktopUrl) {
            if (!desktopUrl) return "";
            var urlStr = String(desktopUrl);
            // Accept file:// URLs or bare paths
            if (urlStr.indexOf("file://") !== 0 && urlStr.indexOf("/") !== 0) return "";
            var xhr = new XMLHttpRequest();
            xhr.open("GET", urlStr, false);
            try {
                xhr.send();
                var text = xhr.responseText || "";
                var lines = text.split("\n");
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i].trim();
                    if (line.indexOf("Icon=") === 0) {
                        return line.substring(5).trim();
                    }
                }
            } catch (e) {}
            return "";
        }

        // Cache of resolved icon names to avoid re-reading .desktop files.
        property var _iconNameCache: ({})

        // Look up the real icon name for a pinned favorite by its id.
        function iconSourceForId(id) {
            if (_iconNameCache[id] !== undefined && _iconNameCache[id] !== "") return _iconNameCache[id];
            var url = urlForAppId(id);
            var iconName = iconNameFromDesktopFile(url);
            if (!iconName) {
                // Fallback: try the app-list model's decoration as a string.
                var info = lookupAppInfo(id);
                if (info && info.decoration && typeof info.decoration === "string") {
                    iconName = info.decoration;
                }
            }
            if (!iconName && id.indexOf("://") > 0) {
                // Pseudo favorites ("preferred://browser", "preferred://filemanager", …)
                // are not real desktop files: the favorites model resolves them to the
                // actual application, whose decoration is a QIcon that Kirigami.Icon
                // renders directly (same as the grid delegate's `source: model.decoration`).
                var info2 = lookupAppInfo(id);
                if (info2 && info2.decoration && typeof info2.decoration !== "string") {
                    iconName = info2.decoration;
                }
            }
            if (!iconName) iconName = iconForId(id);
            _iconNameCache[id] = iconName;
            return iconName;
        }

        // Look up the real display name for a pinned favorite by its id.
        function nameForId(id) {
            var info = lookupAppInfo(id);
            if (info && info.name) return info.name;
            return displayNameForId(id);
        }

        // Look up the launcher URL for a pinned favorite by its id
        // (used to start a drag from a folder-pop entry).
        function urlForId(id) {
            // Search by the favoriteId role (Qt.UserRole + 3) — matches what is
            // stored in pinnedFoldersData items, regardless of how the model's
            // `favorites` list represents entries.
            var count = globalFavorites.rowCount();
            for (var i = 0; i < count; i++) {
                var idx = globalFavorites.index(i, 0);
                var favId = globalFavorites.data(idx, Qt.UserRole + 3);
                if (favId === id) {
                    try {
                        var u = globalFavorites.data(idx, Qt.UserRole + 10); // kickerUrlRole
                        if (u) return u;
                    } catch (e) {}
                    break;
                }
            }
            return "";
        }

        // Look up the .desktop URL for an app id by searching both the
        // favorites model and the full app-list model.
        function urlForAppId(id) {
            var u = urlForId(id);
            if (u) return u;
            if (sortedAppsModel.sourceModel) {
                for (var i = 0; i < sortedAppsModel.rowCount(); i++) {
                    var midx = sortedAppsModel.index(i, 0);
                    try {
                        if (sortedAppsModel.data(midx, kickerFavoriteIdRole) === id) {
                            var u2 = sortedAppsModel.data(midx, kickerUrlRole);
                            if (u2) return String(u2);
                        }
                    } catch (e) {}
                }
            }
            return "";
        }

        property bool _needsComboRebuild: false

        onAllAppsFoldersDataChanged: {
            if (sortedAppsModel.sourceModel) {
                if (folderAppPickerPopup.visible) {
                    _needsComboRebuild = true
                } else {
                    buildAllAppsCombo()
                }
            }
        }

        function openFolderAppPicker(folderIdx, px, py) {
            folderAppPickerPopup.openForFolder(folderIdx, px, py)
        }

        // ── All Apps combo model helpers ─────────────────────────────────────
        // Kicker role IDs (from plasma-workspace/applets/kicker/actionlist.h)
        readonly property int kickerDisplayRole:     Qt.DisplayRole          // 0
        readonly property int kickerDecorationRole:  Qt.DecorationRole       // 1
        readonly property int kickerDescriptionRole: Qt.UserRole + 1         // 257
        readonly property int kickerGroupRole:       Qt.UserRole + 2         // 258
        readonly property int kickerFavoriteIdRole:  Qt.UserRole + 3         // 259
        readonly property int kickerUrlRole:         Qt.UserRole + 10        // 266
        readonly property int kickerActionListRole:  Qt.UserRole + 9         // 265

        // Fenestra : lettre de section « langue du système » pour le mode alphabétique.
        // Le modèle Kicker amont expose le rôle « group » (Qt.UserRole + 2), renvoyé par
        // AppEntry::group()/groupName(). Ce calcul appartient à l'amont et applique les
        // règles de la locale courante :
        //   • un nom commençant par un chiffre  -> « # »
        //   • ponctuation / symbole / espace    -> « & »
        //   • Hangul                            -> décomposition en jamo (choseong)
        //   • chinois (Han)                     -> translittération ICU => initiale pinyin
        //                                          (« 表情符号… » se range sous B, etc.)
        //   • japonais                          -> Kanji regroupés sous « 漢 », katakana translittérés
        //   • le reste                          -> première lettre du nom
        // On lit donc ce rôle au lieu de fabriquer la lettre soi-même à partir du seul
        // premier caractère (ce qui cassait tout pour les noms non latins : ils tombaient
        // tous dans « # »). On met la lettre en majuscules comme la liste de sections de Kicker.
        function groupForApp(modelIndex, name) {
            var g = "";
            try { g = String(sortedAppsModel.data(modelIndex, kickerGroupRole) || ""); } catch (e) { g = ""; }
            if (g !== "") return g.toUpperCase();
            return groupForName(name);
        }

        // Repli si le rôle « group » est indisponible (modèle sans champ group) :
        // première lettre ASCII en majuscule, sinon « # ».
        function groupForName(name) {
            var n = String(name || "");
            var c = n.length > 0 ? n.charAt(0).toUpperCase() : "#";
            if (c < "A" || c > "Z") c = "#";
            return c;
        }

        function lookupAppInfo(favId) {
            for (var i = 0; i < sortedAppsModel.rowCount(); i++) {
                var midx = sortedAppsModel.index(i, 0);
                if (sortedAppsModel.data(midx, kickerFavoriteIdRole) === favId) {
                    return {
                        name:        sortedAppsModel.data(midx, kickerDisplayRole)    || displayNameForId(favId),
                        decoration:  sortedAppsModel.data(midx, kickerDecorationRole) || iconForId(favId),
                        description: sortedAppsModel.data(midx, kickerDescriptionRole) || ""
                    };
                }
            }
            // Pseudo favorites ("preferred://browser", …) never appear in the app
            // list: the favorites model resolves them to the real application.
            var count = globalFavorites.rowCount();
            for (var j = 0; j < count; j++) {
                var gidx = globalFavorites.index(j, 0);
                if (globalFavorites.data(gidx, kickerFavoriteIdRole) === favId) {
                    var gName = globalFavorites.data(gidx, kickerDisplayRole);
                    var gDeco = globalFavorites.data(gidx, kickerDecorationRole);
                    return {
                        name:        gName || displayNameForId(favId),
                        decoration:  gDeco || iconForId(favId),
                        description: globalFavorites.data(gidx, kickerDescriptionRole) || ""
                    };
                }
            }
            return { name: displayNameForId(favId), decoration: iconForId(favId), description: "" };
        }

        // Build the combined pinned model: non-foldered pinned apps and pinned
        // folder tiles, in the shared order stored in `pinnedOrderData` (so a
        // folder can sit anywhere, including at the very end).
        // `pinnedComboKeys` describes the expected content; rebuilding only when it
        // actually differs avoids clearing/re-creating every tile (visible flicker).
        property var pinnedComboKeys: []
        property int pinnedBuiltRows: -1

        // ── Dossiers épinglés et favoris Kicker ────────────────────────────
        // Un lanceur rangé dans un dossier du menu Démarrer reste listé par
        // « pinnedFoldersData » même une fois le favori Kicker supprimé : sans
        // filtrage il continuerait d'apparaître dans le dossier, comme si
        // « Désépingler du menu Démarrer » n'avait rien fait — que le retrait
        // vienne d'ici, de miryu-search ou des réglages système.
        // Les dossiers ne sont qu'une liste d'organisation : c'est le favori
        // Kicker qui fait foi. On reconstruit donc, à chaque changement du
        // modèle de favoris, l'ensemble des identifiants réellement épinglés
        // (rôle FavoriteIdRole = AppEntry::id(), c'est-à-dire exactement la
        // ressource enregistrée dans KActivities) et les dossiers n'affichent
        // plus que les lanceurs qui y figurent encore.
        property var idsFavorisActuels: ({})

        function reconstruireIdsFavoris() {
            var ensemble = ({});
            if (globalFavorites) {
                var n = 0;
                try { n = globalFavorites.rowCount(); } catch (e) { n = 0; }
                for (var i = 0; i < n; i++) {
                    try {
                        var v = String(globalFavorites.data(globalFavorites.index(i, 0),
                                                            Qt.UserRole + 3) || "");
                        if (v.length > 0) ensemble[v] = true;
                    } catch (e2) {}
                }
            }
            idsFavorisActuels = ensemble;
        }

        // Contenu réellement affichable d'un dossier épinglé.
        function itemsDossierEpingles(idx) {
            if (idx < 0 || idx >= pinnedFoldersData.length) return [];
            var items = pinnedFoldersData[idx].items || [];
            var ensemble = idsFavorisActuels;
            var gardes = [];
            for (var i = 0; i < items.length; i++) {
                if (ensemble[items[i]] !== undefined) gardes.push(items[i]);
            }
            return gardes;
        }

        // Purge persistante des lanceurs désépinglés d'un dossier ; les dossiers
        // devenus vides sont dissous. Renvoie true si le dossier existe toujours.
        function purgerDossierEpingle(idx) {
            if (idx < 0 || idx >= pinnedFoldersData.length) return false;
            var dossier = pinnedFoldersData[idx];
            var items = dossier.items || [];
            if (items.length === 0) return true;
            if (!globalFavorites) return true;
            var n = 0;
            try { n = globalFavorites.rowCount(); } catch (e) { return true; }
            if (n === 0) return true;   // modèle pas encore prêt : on ne touche à rien

            var ensemble = idsFavorisActuels;
            var gardes = [];
            for (var i = 0; i < items.length; i++) {
                if (ensemble[items[i]] !== undefined) gardes.push(items[i]);
            }
            if (gardes.length === items.length) return true;

            var dossiers = pinnedFoldersData.slice();
            if (gardes.length === 0) {
                dossiers.splice(idx, 1);
                pinnedFoldersData = dossiers;
                saveFolders();
                return false;
            }
            dossiers[idx] = { name: dossier.name, items: gardes,
                              createdAt: dossier.createdAt || 0 };
            pinnedFoldersData = dossiers;
            saveFolders();
            return true;
        }

        // Synchronisation de TOUS les dossiers épinglés avec les favoris Kicker :
        // tout lanceur qui n'est plus un favori quitte son dossier, et un dossier
        // vidé est dissous. La liste écrite dans la configuration est donc
        // corrigée elle-même, avant tout rendu : c'est ce qui rend « désépingler »
        // immédiat, depuis n'importe où (miryu-search, réglages…), sans avoir à
        // ouvrir le dossier pour déclencher le nettoyage.
        // Sécurité : on ne touche à rien tant que le modèle de favoris est vide,
        // car KAStats le remplit de façon asynchrone — pendant ce laps il ne
        // reflèterait pas la réalité et viderait les dossiers à tort.
        function epurerDossiersEpingles() {
            if (pinnedFoldersData.length === 0 || !globalFavorites) return false;
            var n = 0;
            try { n = globalFavorites.rowCount(); } catch (e) { return false; }
            if (n === 0) return false;

            reconstruireIdsFavoris();
            var ensemble = idsFavorisActuels;
            var gardes = [];
            var modifie = false;
            for (var i = 0; i < pinnedFoldersData.length; i++) {
                var dossier = pinnedFoldersData[i];
                var items = dossier.items || [];
                if (items.length === 0) { gardes.push(dossier); continue; }
                var restants = [];
                for (var j = 0; j < items.length; j++) {
                    if (ensemble[items[j]] !== undefined) restants.push(items[j]);
                }
                if (restants.length === 0) { modifie = true; continue; }  // dissous
                if (restants.length !== items.length) {
                    gardes.push({ name: dossier.name, items: restants,
                                  createdAt: dossier.createdAt || 0 });
                    modifie = true;
                } else {
                    gardes.push(dossier);
                }
            }
            if (!modifie) return false;
            pinnedFoldersData = gardes;
            saveFolders();
            return true;
        }

        function buildPinnedCombo() {
            if (!globalFavorites) return;
            reconstruireIdsFavoris();

            // Build set of foldered app IDs
            var folderedIds = {};
            for (var fi = 0; fi < pinnedFoldersData.length; fi++) {
                var fd0 = pinnedFoldersData[fi];
                if (fd0.items) {
                    for (var ai0 = 0; ai0 < fd0.items.length; ai0++) folderedIds[fd0.items[ai0]] = fi;
                }
            }

            var displayRole = Qt.DisplayRole;
            var decorationRole = Qt.DecorationRole;
            var favoriteIdRole = Qt.UserRole + 3;
            var descRole = Qt.UserRole + 1;
            var urlRole = Qt.UserRole + 10;
            var actionRole = Qt.UserRole + 9;

            // ── Non-foldered pinned apps, keyed by "a:<favoriteId>" ─────────
            var appCount = globalFavorites.rowCount();
            var appInfo = {};
            var appKeys = [];
            for (var i = 0; i < appCount; i++) {
                var idx = globalFavorites.index(i, 0);
                var favId = globalFavorites.data(idx, favoriteIdRole) || "";
                if (favId === "") continue;
                if (folderedIds[favId] !== undefined) continue;
                var akey = pinnedAppKey(favId);
                if (appInfo[akey] !== undefined) continue;
                appKeys.push(akey);
                appInfo[akey] = {
                    favoriteId: favId,
                    sourceRow: i,
                    display: globalFavorites.data(idx, displayRole) || "",
                    decoration: globalFavorites.data(idx, decorationRole) || "",
                    description: globalFavorites.data(idx, descRole) || "",
                    url: String(globalFavorites.data(idx, urlRole) || ""),
                    actionList: globalFavorites.data(idx, actionRole) || []
                };
            }

            // ── Folder tiles, keyed by "f:<identity>" ──────────────────────
            var folderInfo = {};
            var folderKeys = [];
            for (var fj = 0; fj < pinnedFoldersData.length; fj++) {
                var kfd = pinnedFoldersData[fj];
                var fkey = pinnedFolderKey(kfd);
                if (!fkey) fkey = "f:idx:" + fj;
                if (folderInfo[fkey] !== undefined) fkey = fkey + ":" + fj;
                folderInfo[fkey] = {
                    index: fj,
                    name: kfd.name || "",
                    count: itemsDossierEpingles(fj).length
                };
                folderKeys.push(fkey);
            }

            // ── Merge the stored order with the entries that still exist ────
            // Entries gone from the favorites / folders are dropped; brand new
            // apps and folders are appended at the end (unchanged order for
            // users who never reordered anything).
            var order = [];
            var seen = {};
            var oi;
            for (oi = 0; oi < pinnedOrderData.length; oi++) {
                var ok = pinnedOrderData[oi];
                if (appInfo[ok] !== undefined || folderInfo[ok] !== undefined) {
                    if (!seen[ok]) { order.push(ok); seen[ok] = true; }
                }
            }
            for (var ak = 0; ak < appKeys.length; ak++) {
                if (!seen[appKeys[ak]]) { order.push(appKeys[ak]); seen[appKeys[ak]] = true; }
            }
            for (var fk = 0; fk < folderKeys.length; fk++) {
                if (!seen[folderKeys[fk]]) { order.push(folderKeys[fk]); seen[folderKeys[fk]] = true; }
            }

            if (order.join("|") !== pinnedOrderData.join("|")) {
                pinnedOrderData = order;
                savePinnedOrder();
            }

            // Signature used to skip useless rebuilds (it keeps the folder
            // member count so folder tile subtitles stay fresh).
            var keys = [];
            var ki;
            for (ki = 0; ki < order.length; ki++) {
                var entryKey = order[ki];
                if (appInfo[entryKey] !== undefined) {
                    keys.push(entryKey);
                } else {
                    var finfo = folderInfo[entryKey];
                    keys.push("f:" + finfo.index + ":" + finfo.name + ":" + finfo.count);
                }
            }

            // Skip the rebuild when the content is unchanged: a clear()+append()
            // cycle destroys and re-creates every delegate (pop-in animation replay).
            var same = keys.length === pinnedComboKeys.length;
            if (same) {
                for (ki = 0; ki < keys.length; ki++) {
                    if (keys[ki] !== pinnedComboKeys[ki]) { same = false; break; }
                }
            }
            if (same && pinnedComboModel.count === keys.length) {
                pinnedBuiltRows = appCount;
                return;
            }

            pinnedComboKeys = keys;
            pinnedBuiltRows = appCount;
            pinnedComboModel.clear();

            var rowNum = 0;
            for (var ri = 0; ri < order.length; ri++) {
                var rkey = order[ri];
                if (appInfo[rkey] !== undefined) {
                    var app = appInfo[rkey];
                    pinnedComboModel.append({
                        itemType: "app",
                        entryKey: rkey,
                        row: rowNum,
                        display: app.display,
                        name: app.display,
                        decoration: app.decoration,
                        favoriteId: rkey.substring(2),
                        description: app.description,
                        url: app.url,
                        disabled: false,
                        hasActionList: true,
                        actionList: app.actionList,
                        sourceRow: app.sourceRow,
                        folderIdx: -1,
                        indented: false,
                        expanded: false
                    });
                } else {
                    var finfo2 = folderInfo[rkey];
                    pinnedComboModel.append({
                        itemType: "folder",
                        folderScope: "pinned",
                        entryKey: rkey,
                        row: rowNum,
                        display: finfo2.name,
                        name: finfo2.name,
                        decoration: "folder",
                        favoriteId: "",
                        description: i18np("%1 app", "%1 apps", finfo2.count),
                        url: "",
                        disabled: false,
                        hasActionList: true,
                        actionList: [],
                        sourceRow: -1,
                        folderIdx: finfo2.index,
                        indented: false,
                        expanded: false
                    });
                }
                rowNum++;
            }
        }

        function buildAllAppsCombo() {
            // détache le modèle pendant la reconstruction : un seul recalcul à la fin,
            // au lieu d'un par insertion (source de la latence en mode Grille)
            allAppsGrid.model = null;
            allAppsComboModel.clear();
            if (!sortedAppsModel.sourceModel) { allAppsGrid.model = allAppsComboModel; return; }

            var displayRole    = kickerDisplayRole;
            var decorationRole = kickerDecorationRole;
            var favoriteIdRole = kickerFavoriteIdRole;
            var descRole       = kickerDescriptionRole;
            var urlRole        = kickerUrlRole;
            var sortMode       = Plasmoid.configuration.allAppsSortMode;

            // Build set of foldered app IDs
            var folderedIds = {};
            for (var fi = 0; fi < allAppsFoldersData.length; fi++) {
                var fd0 = allAppsFoldersData[fi];
                if (fd0.items) {
                    for (var ai0 = 0; ai0 < fd0.items.length; ai0++) folderedIds[fd0.items[ai0]] = fi;
                }
            }

            // Non-foldered app entries (already sorted by sortedAppsModel)
            var appRows = [];
            for (var i = 0; i < sortedAppsModel.rowCount(); i++) {
                var midx = sortedAppsModel.index(i, 0);
                var favId = favoriteIdRole !== undefined ? (sortedAppsModel.data(midx, favoriteIdRole) || "") : "";
                if (favId !== "" && folderedIds[favId] !== undefined) continue;
                var appName = sortedAppsModel.data(midx, displayRole) || "";
                appRows.push({
                    itemType:    "app",
                    display:     appName,
                    decoration:  sortedAppsModel.data(midx, decorationRole) || "",
                    favoriteId:  favId,
                    group:       groupForApp(midx, appName),
                    description: descRole !== undefined ? (sortedAppsModel.data(midx, descRole) || "") : "",
                    url:         urlRole  !== undefined ? String(sortedAppsModel.data(midx, urlRole)  || "") : "",
                    disabled: false, hasActionList: false,
                    sourceRow: i, folderIdx: -1, indented: false, expanded: false
                });
            }

            // Folder entries
            var folderRows = [];
            for (var fi2 = 0; fi2 < allAppsFoldersData.length; fi2++) {
                var fd2 = allAppsFoldersData[fi2];
                folderRows.push({
                    itemType:    "folder",
                    display:     fd2.name,
                    decoration:  "folder",
                    favoriteId:  "",
                    group:       groupForName(fd2.name),
                    description: i18np("%1 app", "%1 apps", fd2.items ? fd2.items.length : 0),
                    url: "",
                    disabled: false, hasActionList: true,
                    sourceRow: -1, folderIdx: fi2, indented: false, expanded: false
                });
            }

            // Sort folder entries per mode
            if (sortMode === 0 || sortMode === 4)
                folderRows.sort(function(a, b) { return a.display.localeCompare(b.display); });
            else if (sortMode === 1)
                folderRows.sort(function(a, b) { return b.display.localeCompare(a.display); });
            else if (sortMode === 2)
                folderRows.sort(function(a, b) { return (allAppsFoldersData[b.folderIdx].createdAt||0) - (allAppsFoldersData[a.folderIdx].createdAt||0); });
            else if (sortMode === 3)
                folderRows.sort(function(a, b) { return (allAppsFoldersData[a.folderIdx].createdAt||0) - (allAppsFoldersData[b.folderIdx].createdAt||0); });

            // Fenestra : en tri alphabétique (modes 0/1) le modèle Kicker amont fournit les
            // entrées déjà ordonnées « langue du système » (AppsModel::sortEntries trie par
            // groupe puis nom via QCollator ; cf. plasma-workspace/applets/kicker). Le proxy
            // ne les retrie donc plus (sortRoleName vide) : appRows arrive en ordre croissant.
            // Pour le mode 1 (Z→A) on inverse simplement cette liste, ce qui conserve l'ordre
            // de collation au lieu de le casser par un tri « display » brut.
            if (sortMode === 1) appRows.reverse();

            // Combine based on sort mode
            var combined = [];
            if (sortMode === 4) {
                combined = folderRows.concat(appRows);
            } else if (sortMode === 0) {
                var ai = 0, fri = 0;
                while (ai < appRows.length && fri < folderRows.length) {
                    if (appRows[ai].display.localeCompare(folderRows[fri].display) <= 0) combined.push(appRows[ai++]);
                    else combined.push(folderRows[fri++]);
                }
                while (ai < appRows.length)   combined.push(appRows[ai++]);
                while (fri < folderRows.length) combined.push(folderRows[fri++]);
            } else if (sortMode === 1) {
                var ai2 = 0, fri2 = 0;
                while (ai2 < appRows.length && fri2 < folderRows.length) {
                    if (appRows[ai2].display.localeCompare(folderRows[fri2].display) >= 0) combined.push(appRows[ai2++]);
                    else combined.push(folderRows[fri2++]);
                }
                while (ai2 < appRows.length)   combined.push(appRows[ai2++]);
                while (fri2 < folderRows.length) combined.push(folderRows[fri2++]);
            } else {
                // Modes 2/3: newest folders first, oldest folders last
                combined = (sortMode === 2) ? folderRows.concat(appRows) : appRows.concat(folderRows);
            }

            if (sortMode === 0 || sortMode === 1) { // séparateurs A/B/C... aussi en mode Grille
                var withHeaders = [];
                var lastLetter = null;
                // nombre de colonnes réel de la grille (1 en mode Liste : jamais de complément nécessaire)
                var gridCols = (Plasmoid.configuration.allAppsViewMode === 1 && allAppsGrid.columnsCount > 1)
                               ? allAppsGrid.columnsCount : 1;
                for (var hi = 0; hi < combined.length; hi++) {
                    var row = combined[hi];
                    // Fenestra : la lettre provient du rôle « group » du modèle Kicker (voir
                    // groupForApp) et suit donc la langue du système : les noms chinois sont
                    // rangés par initiale pinyin, les noms Hangul par jamo, etc. On ne
                    // recalcule plus la lettre à partir du seul premier caractère.
                    var letter = (row.group && row.group.length > 0) ? row.group : groupForName(row.display);
                    if (letter !== lastLetter) {
                        if (gridCols > 1 && withHeaders.length % gridCols !== 0) {
                            var manque = gridCols - (withHeaders.length % gridCols);
                            for (var bi = 0; bi < manque; bi++) {
                                withHeaders.push({
                                    itemType: "blank",
                                    display: "", decoration: "", favoriteId: "", group: "", description: "", url: "",
                                    disabled: true, hasActionList: false,
                                    sourceRow: -1, folderIdx: -1, indented: false, expanded: false
                                });
                            }
                        }
                        withHeaders.push({
                            itemType: "letterHeader",
                            display: letter,
                            decoration: "",
                            favoriteId: "",
                            group: letter,
                            description: "",
                            url: "",
                            disabled: false, hasActionList: false,
                            sourceRow: -1, folderIdx: -1, indented: false, expanded: false
                        });
                        // complète le reste de la ligne : la lettre occupe toute la rangée à elle seule
                        if (gridCols > 1) {
                            for (var bi2 = 0; bi2 < gridCols - 1; bi2++) {
                                withHeaders.push({
                                    itemType: "blank",
                                    display: "", decoration: "", favoriteId: "", group: "", description: "", url: "",
                                    disabled: true, hasActionList: false,
                                    sourceRow: -1, folderIdx: -1, indented: false, expanded: false
                                });
                            }
                        }
                        lastLetter = letter;
                    }
                    withHeaders.push(row);
                }
                combined = withHeaders;
            }

            for (var ci = 0; ci < combined.length; ci++) allAppsComboModel.append(combined[ci]);
            allAppsGrid.model = allAppsComboModel; // réattache : un seul recalcul ici
        }

        // Descend récursivement dans les sous-catégories d'un modèle (ex: Jeux -> Arcade
        // -> ...) et ne garde que les vraies applis (favoriteId non vide), peu importe la
        // profondeur. Générique : marche pour n'importe quelle catégorie à sous-groupes.
        function collectCategoryApps(model, out, seen) {
            if (!model) return;
            var n = 0;
            try { n = model.rowCount(); } catch (e) { return; }
            for (var i = 0; i < n; i++) {
                var idx = model.index(i, 0);
                var fid = "";
                try { fid = String(model.data(idx, kickerFavoriteIdRole) || ""); } catch (e2) { fid = ""; }
                if (fid !== "" && seen[fid]) continue; // déjà vu via une autre sous-catégorie
                if (fid !== "") {
                    seen[fid] = true;
                    out.push({
                        display: String(model.data(idx, kickerDisplayRole) || ""),
                        decoration: model.data(idx, kickerDecorationRole) || "",
                        favoriteId: fid,
                        description: String(model.data(idx, kickerDescriptionRole) || ""),
                        url: String(model.data(idx, kickerUrlRole) || ""),
                        disabled: false, hasActionList: false,
                        srcRow: i,
                        srcModel: model
                    });
                } else {
                    var child = null;
                    try { child = model.modelForRow(i); } catch (e3) { child = null; }
                    if (child) collectCategoryApps(child, out, seen);
                }
            }
        }

        function toggleFolderExpand(folderComboIdx) {
            if (folderComboIdx < 0 || folderComboIdx >= allAppsComboModel.count) return;
            var entry = allAppsComboModel.get(folderComboIdx);
            if (entry.itemType !== "folder") return;
            var fi = entry.folderIdx;
            if (fi < 0 || fi >= allAppsFoldersData.length) return;
            var folder = allAppsFoldersData[fi];

            if (!entry.expanded) {
                allAppsComboModel.set(folderComboIdx, { expanded: true });
                var items = folder.items || [];
                for (var i = 0; i < items.length; i++) {
                    var info = lookupAppInfo(items[i]);
                    allAppsComboModel.insert(folderComboIdx + 1 + i, {
                        itemType:    "app",
                        display:     info.name,
                        decoration:  info.decoration,
                        favoriteId:  items[i],
                        description: info.description,
                        url: "",
                        disabled: false, hasActionList: false,
                        sourceRow: -1, folderIdx: fi, indented: true, expanded: false
                    });
                }
            } else {
                allAppsComboModel.set(folderComboIdx, { expanded: false });
                while (folderComboIdx + 1 < allAppsComboModel.count) {
                    var next = allAppsComboModel.get(folderComboIdx + 1);
                    if (next.indented && next.folderIdx === fi) allAppsComboModel.remove(folderComboIdx + 1);
                    else break;
                }
            }
        }

        // ── Launch Frequency Tracking ───────────────────────────────────────
        property var launchCounts: ({})
        property string _launchCountsRaw: ""

        function loadLaunchCounts() {
            var raw = Plasmoid.configuration.appLaunchCounts || "";
            if (raw === _launchCountsRaw) return;
            _launchCountsRaw = raw;
            if (raw.length === 0) { launchCounts = ({}); return; }
            try { launchCounts = JSON.parse(raw); } catch(e) { launchCounts = ({}); }
        }

        function saveLaunchCounts() {
            _launchCountsRaw = JSON.stringify(launchCounts);
            Plasmoid.configuration.appLaunchCounts = _launchCountsRaw;
        }

        // Returns the current workflow bucket key: "day-slot"
        // day: 0=Sun…6=Sat, slot: 0=night(0-5h), 1=morning(6-11h), 2=afternoon(12-17h), 3=evening(18-23h)
        function currentBucket() {
            var now = new Date();
            var day = now.getDay();
            var h = now.getHours();
            var slot = h < 6 ? 0 : h < 12 ? 1 : h < 18 ? 2 : 3;
            return day + "-" + slot;
        }

        // Returns a 0-10 score for how strongly an app matches the current time/day slot
        function workflowScore(appId) {
            if (!appId) return 0;
            var entry = launchCounts[appId];
            if (!entry || typeof entry !== "object") return 0;
            var bucket = currentBucket();
            var bucketCount = (entry.buckets && entry.buckets[bucket]) || 0;
            var total = entry.total || 1;
            return Math.round((bucketCount / total) * 10);
        }

        function recordLaunch(appId) {
            if (!appId || appId === "") return;
            var updated = JSON.parse(JSON.stringify(launchCounts));
            var bucket = currentBucket();
            var prev = updated[appId];
            // Migrate legacy plain-number entries to the new schema
            var prevTotal = (typeof prev === "number") ? prev : (prev && prev.total ? prev.total : 0);
            var prevBuckets = (prev && typeof prev === "object" && prev.buckets) ? prev.buckets : {};
            prevBuckets[bucket] = (prevBuckets[bucket] || 0) + 1;
            updated[appId] = { total: prevTotal + 1, buckets: prevBuckets, last: Date.now() };
            launchCounts = updated;
            saveLaunchCounts();
            forgetNewApp(appId);
        }

        // ── Smart Context ────────────────────────────────────────────────────
        property string contextLabel: {
            var counts = rootItem.launchCounts;
            // Check for workflow pattern: any app with bucket score >= 6
            var hasWorkflow = false;
            for (var id in counts) {
                if (rootItem.workflowScore(id) >= 6) { hasWorkflow = true; break; }
            }
            if (hasWorkflow) {
                var now = new Date();
                var days = [i18n("Sunday"), i18n("Monday"), i18n("Tuesday"),
                            i18n("Wednesday"), i18n("Thursday"), i18n("Friday"), i18n("Saturday")];
                var h = now.getHours();
                var dayName = days[now.getDay()];
                if (h < 6)  return i18n("%1 night session", dayName);
                if (h < 12) return i18n("%1 morning picks", dayName);
                if (h < 18) return i18n("%1 afternoon picks", dayName);
                return i18n("%1 evening picks", dayName);
            }
            // Frequency-based fallback
            var topCount = 0;
            for (var aid in counts) {
                var entry = counts[aid];
                var t = (entry && typeof entry === "object") ? (entry.total || 0) : (entry || 0);
                if (t > topCount) topCount = t;
            }
            if (topCount >= 10) return i18n("Your top picks");
            if (topCount >= 5)  return i18n("Frequently used");
            // Time-of-day fallback
            var hour = new Date().getHours();
            if (hour >= 5  && hour < 9)  return i18n("Your morning session");
            if (hour >= 9  && hour < 12) return i18n("Good morning apps");
            if (hour >= 12 && hour < 14) return i18n("Midday picks");
            if (hour >= 14 && hour < 18) return i18n("Afternoon session");
            if (hour >= 18 && hour < 21) return i18n("Evening apps");
            return i18n("Late night");
        }

        // ── Command Palette ──────────────────────────────────────────────────
        readonly property var paletteCommands: ([
            { name: "lock",       icon: "system-lock-screen",  desc: i18n("Lock the screen"),       cmd: "loginctl lock-session" },
            { name: "sleep",      icon: "system-suspend",      desc: i18n("Suspend to RAM"),         cmd: "systemctl suspend" },
            { name: "reboot",     icon: "system-reboot",       desc: i18n("Restart the computer"),   cmd: "systemctl reboot" },
            { name: "shutdown",   icon: "system-shutdown",     desc: i18n("Shut down the computer"), cmd: "systemctl poweroff" },
            { name: "screenshot", icon: "spectacle",           desc: i18n("Take a screenshot"),      cmd: "spectacle --gui" },
            { name: "settings",   icon: "preferences-system",  desc: i18n("Open System Settings"),   cmd: "systemsettings" },
            { name: "files",      icon: "system-file-manager", desc: i18n("Open file manager"),      cmd: "dolphin" },
            { name: "terminal",   icon: "utilities-terminal",  desc: i18n("Open a terminal"),        cmd: "konsole" },
            { name: "logout",     icon: "system-log-out",      desc: i18n("Log out"),                cmd: "loginctl terminate-user " + Qt.application.name }
        ].concat(PluginSystem.extraCommands()))

        Component.onCompleted: {
            // Calculator — handled inline in QML, stub so it appears in registeredPlugins()
            PluginSystem.register({
                name: "Calculator",
                icon: "accessories-calculator",
                commands: [],
                handleQuery: function(q) { return null; },
                searchResults: function(q) { return []; }
            });
        }

        // Aggregated plugin search results — updated whenever the runner query changes
        property var pluginResults: []

        function refreshPluginResults(query) {
            pluginResults = (query && query.length >= 2)
                            ? PluginSystem.searchResults(query)
                            : [];
        }

        Plasma5Support.DataSource {
            id: executable
            engine: "executable"
            connectedSources: []

            property bool dolphinRunning: false

            onNewData: function (source, data) {
                if (source.includes("pgrep")) {
                    dolphinRunning = data["exit code"] === 0;
                }
                disconnectSource(source);
            }

            function exec(cmd) {
                connectSource(cmd);
            }

            function checkDolphin() {
                connectSource("pgrep dolphin");
            }
        }

        Kirigami.Heading {
            id: dummyHeading
            visible: false
            width: 0
            level: 5
        }

        TextMetrics {
            id: headingMetrics
            font: dummyHeading.font
        }

        KItemModels.KSortFilterProxyModel {
            id: sortedAppsModel

            // Fenestra : en mode alphabétique (0 = A→Z, 1 = Z→A), le tri revient au modèle
            // Kicker amont. AppsModel::sortEntries ordonne en effet ses entrées par groupe
            // puis par nom via QCollator, c.-à-d. selon les règles de collation de la locale
            // du système (les noms chinois sont triés par pinyin, etc.). Un « sortRoleName »
            // vide désactive le tri interne du proxy et préserve cet ordre amont ; on évite
            // ainsi le tri « display » brut (comparaison de points de code) qui rangeait tous
            // les noms non latins à la fin. Les modes 2/3 (url) et 4 (description) gardent
            // leur tri propre.
            sortRoleName: {
                var m = Plasmoid.configuration.allAppsSortMode;
                if (m === 4) return "description";
                if (m === 2 || m === 3) return "url";
                return "";
            }
            // Fenestra : quand le proxy trie lui-même, il le fait selon la locale du système
            sortCaseSensitivity: Qt.CaseInsensitive
            isSortLocaleAware: true
            sortOrder: {
                var m = Plasmoid.configuration.allAppsSortMode;
                return (m === 1 || m === 3) ? Qt.DescendingOrder : Qt.AscendingOrder;
            }

            function trigger(row, actionId, argument) {
                var srcIdx = mapToSource(index(row, 0))
                if (srcIdx.valid && sourceModel)
                    sourceModel.trigger(srcIdx.row, actionId, argument)
            }

            property var favoritesModel: sourceModel ? sourceModel.favoritesModel : null
        }

        // Pinned favorites with apps that belong to a folder filtered out
        KItemModels.KSortFilterProxyModel {
            id: pinnedFavoritesFiltered
            sourceModel: globalFavorites
            filterRowCallback: function(sourceRow, sourceParent) {
                var idx = sourceModel.index(sourceRow, 0, sourceParent);
                var favId = sourceModel.data(idx, Qt.UserRole + 3) || "";
                if (!favId) return true;
                var folders = rootItem.pinnedFoldersData;
                for (var i = 0; i < folders.length; i++) {
                    if (folders[i].items && folders[i].items.indexOf(favId) >= 0) return false;
                }
                return true;
            }
            property var favoritesModel: sourceModel ? sourceModel.favoritesModel : null
            function trigger(row, actionId, argument) {
                var srcIdx = mapToSource(index(row, 0));
                if (srcIdx.valid && sourceModel) sourceModel.trigger(srcIdx.row, actionId, argument);
            }
            function isFavorite(id) { return sourceModel ? sourceModel.isFavorite(id) : false; }
            function addFavorite(id, row) {
                if (!sourceModel) return;
                var srcRow = -1;
                if (row >= 0 && row < count) {
                    var mi = mapToSource(index(row, 0));
                    if (mi.valid) srcRow = mi.row;
                }
                sourceModel.addFavorite(id, srcRow);
            }
            function moveRow(from, to) {
                if (!sourceModel || from < 0 || to < 0 || from >= count || to >= count) return;
                var fromSrc = mapToSource(index(from, 0)).row;
                var toSrc = mapToSource(index(to, 0)).row;
                sourceModel.moveRow(fromSrc, toSrc);
            }
        }

        // Recommandations : seulement les 6 éléments affichés (pas de lignes cachées qui cassent le clavier)
        KItemModels.KSortFilterProxyModel {
            id: docsLimitedModel
            filterRowCallback: function (sourceRow, sourceParent) { return sourceRow < 6; }

            function trigger(row, actionId, argument) {
                var srcIdx = mapToSource(index(row, 0));
                if (srcIdx.valid && sourceModel)
                    return sourceModel.trigger(srcIdx.row, actionId, argument);
            }

            property var favoritesModel: sourceModel ? sourceModel.favoritesModel : null
        }

        // ── Dates des recommandations (date de modification des fichiers, lue avec stat) ──
        property var docEpochs: ({})       // url -> secondes (date de modification)
        property var docDates: ({})        // url -> texte affiché (« jeudi à 10:05 »)

        function formatDocDate(epochSeconds) {
            var d = new Date(epochSeconds * 1000);
            var now = new Date();
            var loc = Qt.locale();
            var time = Qt.formatTime(d, "HH:mm");
            var dayMs = 86400000;
            var startToday = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
            var startDoc = new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime();
            var diffDays = Math.round((startToday - startDoc) / dayMs);
            if (diffDays <= 0) return i18n("today at %1", time);
            if (diffDays === 1) return i18n("yesterday at %1", time);
            if (diffDays < 7) return i18n("%1 at %2", loc.dayName(d.getDay(), Locale.LongFormat), time);
            var s = d.getDate() + " " + loc.monthName(d.getMonth(), Locale.ShortFormat);
            if (d.getFullYear() !== now.getFullYear()) s += " " + d.getFullYear();
            return s;
        }

        // heure « à la Windows » : « Il y a 18h » pendant 24 h, puis « hier à … », « jeudi à 10:05 »
        function formatRecentTime(epochSeconds) {
            var diffMin = Math.floor((Date.now() - epochSeconds * 1000) / 60000);
            if (diffMin < 1) return i18n("Just now");
            if (diffMin < 60) return i18n("%1 min ago", diffMin);
            if (diffMin < 1440) return i18n("%1 h ago", Math.floor(diffMin / 60));
            return formatDocDate(epochSeconds);
        }

        function refreshDocDates() {
            var urls = [];
            var src = docsLimitedModel.sourceModel;
            if (!src) return;
            for (var i = 0; i < Math.min(src.rowCount(), 60); i++) {
                var u = String(src.data(src.index(i, 0), kickerUrlRole));
                if (u.indexOf("file://") === 0) urls.push(u);
            }
            if (urls.length === 0) { rebuildDocModels(); return; }
            // date de DERNIÈRE UTILISATION (base d'activité KDE, comme Dolphin),
            // repli sur la date de modification ; adresses complètes, décodées côté Python
            var quoted = urls.map(function (u) {
                return "'" + u.replace(/'/g, "'\\''") + "'";
            }).join(" ");
            var lecteur = "import sys, os, sqlite3\nfrom urllib.parse import unquote\ndb = os.path.expanduser(\"~/.local/share/kactivitymanagerd/resources/database\")\nusage = {}\ntry:\n    c = sqlite3.connect(\"file:\" + db + \"?mode=ro\", uri=True, timeout=2)\n    for r, t in c.execute(\"SELECT targettedResource, MAX(lastUpdate) FROM ResourceScoreCache GROUP BY targettedResource\"):\n        if t: usage[r] = int(t)\nexcept Exception:\n    pass\nfor u in sys.argv[1:]:\n    p = unquote(u[7:]) if u.startswith(\"file://\") else u\n    t = usage.get(p) or usage.get(u) or usage.get(\"file://\" + p)\n    if not t:\n        try: t = int(os.stat(p).st_mtime)\n        except Exception: t = 0\n    print(t)\n";
            var cmd = "python3 -c '" + lecteur + "' " + quoted;
            statSource.pending[cmd] = urls;
            statSource.connectSource(cmd);
        }

        Plasma5Support.DataSource {
            id: statSource
            engine: "executable"
            connectedSources: []
            property var pending: ({})

            onNewData: function (source, data) {
                var lines = String(data["stdout"] || "").split("\n");
                var urls = statSource.pending[source] || [];
                var res = JSON.parse(JSON.stringify(rootItem.docDates));
                var eps = JSON.parse(JSON.stringify(rootItem.docEpochs));
                for (var i = 0; i < urls.length; i++) {
                    var t = parseInt(lines[i]);
                    if (t > 0) { res[urls[i]] = rootItem.formatDocDate(t); eps[urls[i]] = t; }
                }
                rootItem.docDates = res;
                rootItem.docEpochs = eps;
                rootItem.rebuildDocModels();
                delete statSource.pending[source];
                disconnectSource(source);
            }
        }

        // ── Recommandations triées par date (la plus récente d'abord) ──
        // listes construites ici : page 1 = 6 plus récents, page complète = 7 derniers jours
        function resolveDocRow(url, hintRow) {
            var m = docsLimitedModel.sourceModel;
            if (!m) return -1;
            var n = m.rowCount();
            if (hintRow >= 0 && hintRow < n && String(m.data(m.index(hintRow, 0), kickerUrlRole)) === url) return hintRow;
            for (var i = 0; i < n; i++) {
                if (String(m.data(m.index(i, 0), kickerUrlRole)) === url) return i;
            }
            return -1;
        }

        function triggerDoc(entry, actionId, argument) {
            if (!entry) return false;
            var r = resolveDocRow(entry.url, entry.srcRow);
            if (r < 0) { refreshDocDates(); return false; }
            return docsLimitedModel.sourceModel.trigger(r, actionId, argument);
        }

        function docActionList(entry) {
            if (!entry) return [];
            var r = resolveDocRow(entry.url, entry.srcRow);
            if (r < 0) return [];
            var m = docsLimitedModel.sourceModel;
            return m.data(m.index(r, 0), kickerActionListRole) || [];
        }

        function rebuildDocModels() {
            var m = docsLimitedModel.sourceModel;
            docsTopModel.clear();
            docsWeekModel.clear();
            if (!m) return;
            var now = Date.now() / 1000;
            var rows = [];
            for (var i = 0; i < Math.min(m.rowCount(), 60); i++) {
                var u = String(m.data(m.index(i, 0), kickerUrlRole));
                rows.push({ i: i, url: u, t: docEpochs[u] || 0 });
            }
            // plus récent d'abord ; sans date : à la fin, dans l'ordre d'usage de Plasma
            rows.sort(function (a, b) { return (b.t - a.t) || (a.i - b.i); });
            for (var k = 0; k < rows.length; k++) {
                var mi = m.index(rows[k].i, 0);
                var deco = m.data(mi, kickerDecorationRole);
                var entry = {
                    display: String(m.data(mi, kickerDisplayRole) || ""),
                    decoration: (typeof deco === "string") ? deco : "",
                    description: String(m.data(mi, kickerDescriptionRole) || ""),
                    favoriteId: String(m.data(mi, kickerFavoriteIdRole) || ""),
                    url: rows[k].url,
                    hasActionList: true,
                    disabled: false,
                    srcRow: rows[k].i
                };
                if (k < 6) docsTopModel.append(entry);
                if (rows[k].t > 0 && now - rows[k].t < 7 * 86400) docsWeekModel.append(entry);
            }
        }

        function scheduleDocsRefresh() { docsRefreshTimer.restart(); }

        Timer {
            id: docsRefreshTimer
            interval: 500
            repeat: false
            onTriggered: rootItem.refreshDocDates()
        }

        ListModel {
            id: docsTopModel
            property var favoritesModel: docsLimitedModel.favoritesModel
            function trigger(row, actionId, argument) { return rootItem.triggerDoc(get(row), actionId, argument); }
            function actionListForRow(row) { return rootItem.docActionList(get(row)); }
        }

        ListModel {
            id: docsWeekModel
            property var favoritesModel: docsLimitedModel.favoritesModel
            function trigger(row, actionId, argument) { return rootItem.triggerDoc(get(row), actionId, argument); }
            function actionListForRow(row) { return rootItem.docActionList(get(row)); }
        }

        // ── Le curseur de frappe reste dans la recherche ──
        // si le focus part vers une liste sans navigation au clavier (simple survol), on le rend à la recherche
        Connections {
            id: keepSearchFocus
            target: root
            function onActiveFocusItemChanged() {
                if (!root.visible || rootItem.keyNavRecently()) return;
                var p = root.activeFocusItem;
                while (p) {
                    if (p === globalFavoritesGrid || p === documentsGrid || p === allAppsGrid
                            || p === recentAllGrid || p === allAppsCategoryGrid) {
                        Qt.callLater(function () {
                            if (root.visible && !rootItem.keyNavRecently()) searchField.forceActiveFocus();
                        });
                        return;
                    }
                    p = p.parent;
                }
            }
        }

        // ── Nouvelles applications : détection à l'installation, notification, marquage « nouveau » ──
        // incrémenté à chaque rafraîchissement du catalogue (les sous-modèles des catégories sont alors remplacés)
        property int categoryRevision: 0
        property var knownApps: []          // fichiers .desktop connus
        property var newApps: ({})          // identifiant de l'appli -> { t, cat, name }
        property var pendingApps: []        // détectées, en attente de leur catégorie
        property int pendingRounds: 0
        property bool newAppsLoaded: false
        readonly property bool newAppsReady: Plasmoid.configuration.knownApps !== undefined

        readonly property string desktopListCmd: "for d in $(echo \"${XDG_DATA_HOME:-$HOME/.local/share}:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}:/var/lib/flatpak/exports/share:$HOME/.local/share/flatpak/exports/share\" | tr ':' ' '); do ls -1 \"$d/applications\" 2>/dev/null; done | grep '\\.desktop$' | sort -u"

        function shq(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'"; }

        function saveKnownApps() { Plasmoid.configuration.knownApps = JSON.stringify(knownApps); }
        function saveNewApps() { Plasmoid.configuration.newApps = JSON.stringify(newApps); }

        function loadNewApps() {
            try { knownApps = JSON.parse(Plasmoid.configuration.knownApps || "[]"); } catch (e) { knownApps = []; }
            var stored = {};
            try { stored = JSON.parse(Plasmoid.configuration.newApps || "{}"); } catch (e) { stored = {}; }
            // une nouveauté est oubliée après 7 jours
            var keep = {}, changed = false, now = Date.now();
            for (var k in stored) {
                if (stored[k] && now - stored[k].t < 7 * 86400000) keep[k] = stored[k];
                else changed = true;
            }
            newApps = keep;
            if (changed) saveNewApps();
            newAppsLoaded = true;
        }

        function handleDesktopList(list) {
            if (!newAppsReady || list.length === 0) return;
            if (!newAppsLoaded) loadNewApps();
            if (knownApps.length === 0) {              // 1er passage : état de départ, sans notification
                knownApps = list;
                saveKnownApps();
                return;
            }
            var known = {};
            for (var i = 0; i < knownApps.length; i++) known[knownApps[i]] = true;
            var added = [];
            for (var j = 0; j < list.length; j++) if (!known[list[j]]) added.push(list[j]);
            if (added.length === 0 && list.length === knownApps.length) return;
            knownApps = list;
            saveKnownApps();
            if (added.length > 0) {
                pendingApps = pendingApps.concat(added);
                pendingRounds = 0;
                resolveTimer.interval = 3000;
                resolveTimer.restart();
            }
        }

        // recherche de la catégorie des nouvelles applis dans les catégories du menu
        function resolvePendingApps() {
            if (pendingApps.length === 0) return;
            var want = {};
            for (var i = 0; i < pendingApps.length; i++) want[pendingApps[i]] = true;
            var found = [], foundIds = {};
            for (var c = 0; c < categoryRootModel.rowCount(); c++) {
                var sub = categoryRootModel.modelForRow(c);
                if (!sub) continue;
                var catName = String(categoryRootModel.data(categoryRootModel.index(c, 0), Qt.DisplayRole) || sub.description || "");
                for (var r = 0; r < sub.rowCount(); r++) {
                    var idx = sub.index(r, 0);
                    var fid = String(sub.data(idx, kickerFavoriteIdRole) || "");
                    if (want[fid] && !foundIds[fid]) {
                        foundIds[fid] = true;
                        found.push({ id: fid,
                                     name: String(sub.data(idx, kickerDisplayRole) || fid),
                                     icon: sub.data(idx, kickerDecorationRole),
                                     cat: catName });
                    }
                }
            }
            var missing = pendingApps.filter(function (id) { return !foundIds[id]; });
            if (missing.length > 0 && pendingRounds < 10) {
                // catalogue pas encore à jour : on réessaie un peu plus tard
                pendingApps = missing;
                pendingRounds++;
                resolveTimer.interval = 5000;
                resolveTimer.restart();
            } else {
                pendingApps = [];
                pendingRounds = 0;
            }
            if (found.length === 0) return;
            var updated = JSON.parse(JSON.stringify(newApps));
            for (var f = 0; f < found.length; f++) updated[found[f].id] = { t: Date.now(), cat: found[f].cat, name: found[f].name };
            newApps = updated;
            saveNewApps();
            notifyNewApps(found);
        }

        function notifyNewApps(found) {
            if (Plasmoid.configuration.notifyNewApps === false) return;
            var title, body, icon;
            if (found.length === 1) {
                title = i18n("New application");
                body = i18n("%1 is installed — filed under “%2”", found[0].name, found[0].cat);
                icon = (typeof found[0].icon === "string" && found[0].icon !== "") ? found[0].icon : "applications-other";
            } else {
                title = i18np("%1 new application", "%1 new applications", found.length);
                body = found.slice(0, 4).map(function (f) { return f.name + " (" + f.cat + ")"; }).join(", ")
                       + (found.length > 4 ? "…" : "");
                icon = "applications-other";
            }
            var cmd = "(command -v notify-send >/dev/null 2>&1 && notify-send -a 'Menu Démarrer' -i " + shq(icon) + " -u low "
                      + shq(title) + " " + shq(body) + ") || kdialog --title " + shq(title) + " --passivepopup " + shq(body) + " 8";
            notifySource.connectSource(cmd + " #" + Date.now());
        }

        function forgetNewApp(appId) {
            if (!newAppsReady || !newApps[appId]) return;
            var updated = JSON.parse(JSON.stringify(newApps));
            delete updated[appId];
            newApps = updated;
            saveNewApps();
        }

        Plasma5Support.DataSource {
            id: appsWatch
            engine: "executable"
            connectedSources: []
            property string currentSource: ""

            function poll() {
                if (currentSource !== "") disconnectSource(currentSource);
                currentSource = rootItem.desktopListCmd + " #" + Date.now();
                connectSource(currentSource);
            }

            onNewData: function (source, data) {
                var out = String(data["stdout"] || "").trim();
                disconnectSource(source);
                if (source !== currentSource) return;
                rootItem.handleDesktopList(out === "" ? [] : out.split("\n"));
            }
        }

        Plasma5Support.DataSource {
            id: notifySource
            engine: "executable"
            connectedSources: []
            onNewData: function (source, data) { disconnectSource(source); }
        }

        // surveillance toutes les minutes (1er passage 20 s après le chargement)
        Timer {
            id: appsWatchTimer
            interval: 5000
            repeat: true
            running: rootItem.newAppsReady
            onTriggered: {
                interval = 10000;
                appsWatch.poll();
            }
        }

        // laisse au système le temps de mettre le catalogue à jour, puis relit les catégories
        Timer {
            id: resolveTimer
            interval: 6000
            repeat: false
            onTriggered: {
                var first = !root.categoryModelLoaded;
                root.ensureCategoryModel();
                if (!first) categoryRootModel.refresh();
                rootModel.refresh();
            }
        }

        Connections {
            target: categoryRootModel
            function onRefreshed() { rootItem.categoryRevision++; rootItem.resolvePendingApps(); }
        }

        // ── Défilement en cours : les infobulles sont coupées pendant que la liste bouge sous la souris ──
        property bool scrolling: false
        function noteScrolling() {
            scrolling = true;
            scrollEndTimer.restart();
        }

        Timer {
            id: scrollEndTimer
            interval: 350
            repeat: false
            onTriggered: rootItem.scrolling = false
        }

        ListModel {
            id: allAppsComboModel
            // Exposes favoritesModel so delegates can Pin/Unpin via the same KActivities model
            property var favoritesModel: sortedAppsModel.favoritesModel
        }

        // Combined pinned model: non-foldered pinned apps and pinned folder
        // tiles, ordered by rootItem.pinnedOrderData (apps and folders can be
        // interleaved and reordered freely).
        ListModel {
            id: pinnedComboModel
            property var favoritesModel: globalFavorites
            property int dropPlaceholderIndex: -1

            function trigger(row, actionId, argument) {
                if (row < 0 || row >= count) return;
                var e = get(row);
                if (!e) return;
                if (e.itemType === "folder") {
                    // Open the pinned folder content popup
                    folderContentPopup.showAt(e.folderIdx, 0, 0, 0, 0);
                    return;
                }
                // App: forward to the real favorites model by source row
                if (e.sourceRow !== undefined && e.sourceRow >= 0) {
                    globalFavorites.trigger(e.sourceRow, actionId, argument);
                }
            }
            function isFavorite(id) { return globalFavorites.isFavorite(id); }
            function addFavorite(id, row) {
                var srcRow = -1;
                var insertAt = -1;
                if (row >= 0 && row < count) {
                    var e = get(row);
                    if (e && e.sourceRow !== undefined) srcRow = e.sourceRow;
                    insertAt = row;
                }
                globalFavorites.addFavorite(id, srcRow);
                // The display order now lives in rootItem.pinnedOrderData: a new
                // favorite would otherwise always land at the end, wherever it
                // was dropped. Pin it at the hovered slot instead.
                if (insertAt >= 0 && typeof rootItem !== "undefined"
                        && rootItem.pinnedOrderData !== undefined) {
                    var key = rootItem.pinnedAppKey(id);
                    var order = [];
                    for (var i = 0; i < rootItem.pinnedOrderData.length; ++i) {
                        if (rootItem.pinnedOrderData[i] !== key) {
                            order.push(rootItem.pinnedOrderData[i]);
                        }
                    }
                    order.splice(Math.max(0, Math.min(insertAt, order.length)), 0, key);
                    rootItem.pinnedOrderData = order;
                    rootItem.savePinnedOrder();
                    rootItem.pinnedComboKeys = [];
                    // Deferred like moveRow(): the model rebuild must not
                    // destroy the dragged delegate while the drop is handled.
                    Qt.callLater(function() { rootItem.buildPinnedCombo(); });
                }
            }
            function moveRow(from, to) {
                if (from < 0 || to < 0 || from >= count || from === to || count === 0) return;
                if (to >= count) to = count - 1;

                var moving = get(from);
                if (!moving || !moving.entryKey) return;

                // The grid order lives in rootItem.pinnedOrderData, which mixes
                // app keys ("a:<favoriteId>") and folder keys ("f:<identity>").
                // Reordering it is what lets a folder sit anywhere — including
                // before the last app or after every other tile.
                var order = [];
                for (var i = 0; i < count; ++i) {
                    var e = get(i);
                    if (e && e.entryKey) order.push(e.entryKey);
                }
                order.splice(from, 1);
                order.splice(Math.max(0, Math.min(to, order.length)), 0, moving.entryKey);

                if (typeof rootItem !== "undefined" && typeof rootItem.pinnedOrderData !== "undefined") {
                    rootItem.pinnedOrderData = order;
                    rootItem.savePinnedOrder();
                }

                // Reorder in place: GridView animates the move instead of
                // destroying every delegate with a full rebuild.
                // ListModel.move() takes (from, to, n): omitting n throws
                // "Insufficient arguments" and aborts the visual reorder
                // (the saved order only showed up after reopening the menu).
                pinnedComboModel.move(from, to, 1);
                // Delegates derive their itemIndex from the `row` role.
                for (var r = 0; r < pinnedComboModel.count; ++r) {
                    pinnedComboModel.setProperty(r, "row", r);
                }

                // Keep the content signature in sync with the new order so the
                // next buildPinnedCombo() (menu reopen) does not clear and
                // re-create every tile.
                var keys = [];
                for (var k = 0; k < pinnedComboModel.count; ++k) {
                    var ke = pinnedComboModel.get(k);
                    if (!ke) continue;
                    if (ke.itemType === "folder") {
                        keys.push("f:" + ke.folderIdx + ":" + (ke.name || "") + ":"
                                  + (typeof rootItem !== "undefined"
                                     ? rootItem.itemsDossierEpingles(ke.folderIdx).length : 0));
                    } else {
                        keys.push(ke.entryKey);
                    }
                }
                rootItem.pinnedComboKeys = keys;
            }
        }

        // Rebuild the pinned combo model whenever the favorites model changes
        // (apps pinned/unpinned/reordered). The Kicker favorites model is a
        // QAbstractItemModel, so we listen to its structural change signals.
        Connections {
            target: globalFavorites
            function onModelReset() { rootItem.buildPinnedCombo(); }
            function onRowsInserted() { rootItem.buildPinnedCombo(); }
            // Retrait d'un favori : le lanceur quitte aussitôt ses dossiers, sans
            // attendre qu'on les ouvre.
            function onRowsRemoved() {
                rootItem.epurerDossiersEpingles();
                rootItem.buildPinnedCombo();
            }
            function onRowsMoved() { rootItem.buildPinnedCombo(); }
            function onLayoutChanged() { rootItem.buildPinnedCombo(); }
            function onDataChanged() { rootItem.buildPinnedCombo(); }
            // Le modèle de favoris se remplit de façon asynchrone (KAStats) :
            // ce signal garantit une reconstruction dès que la liste est disponible.
            function onFavoritesChanged() { rootItem.buildPinnedCombo(); }
        }

        PC3.TextField {
            id: searchField
            anchors {
                top: parent.top
                topMargin: Kirigami.Units.gridUnit - 10
                left: parent.left
                leftMargin: rootItem.margeCote + 20   // Fenestra : recherche décalée
                // Fenestra : ancre à droite sur le bouton KDE Connect s'il est visible,
                // sinon sur le bord parent (la recherche remplit toute la largeur disponible).
                right: Plasmoid.configuration.kdeConnectShow ? kdeConnectButton.left : parent.right
                rightMargin: Plasmoid.configuration.kdeConnectShow ? (Kirigami.Units.smallSpacing * 2 + 10) : (rootItem.margeCote + 20)
            }
            focus: true
            placeholderText: i18n("Search for apps, settings and documents")
            topPadding: 10
            bottomPadding: 10
            leftPadding: Kirigami.Units.gridUnit + Kirigami.Units.iconSizes.small
            text: ""
            font.pointSize: Kirigami.Theme.defaultFont.pointSize

            background: Rectangle {
                color: Kirigami.Theme.backgroundColor
                radius: 20
                border.width: 1
                border.color: colorWithAlpha(Kirigami.Theme.textColor, 0.05)
            }

            onTextChanged: {
                if (text.startsWith('>') && Plasmoid.configuration.enableShellRunner) {
                    searchDebounce.stop();
                    runnerModel.query = "";
                } else if (text.startsWith('/')) {
                    searchDebounce.stop();
                    runnerModel.query = "";
                } else {
                    searchDebounce.restart();
                }
            }
            Keys.onPressed: event => {
                rootItem.lastNavKeyTime = Date.now();
                if (event.key === Qt.Key_Escape) {
                    event.accepted = true;
                    if (categoryFlyout.visible) {
                        categoryFlyout.close();
                    } else if (viewModePopup.visible) {
                        viewModePopup.visible = false;
                    } else if (root.searching) {
                        searchField.clear();
                    } else if (view.currentIndex === 2) {
                        view.currentIndex = 0;
                    } else {
                        root.toggle();
                    }
                }
                // In '/' palette mode, Down focuses the palette list
                if (searchField.text.startsWith('/') && event.key === Qt.Key_Down) {
                    event.accepted = true;
                    commandPaletteList.currentIndex = 0;
                    commandPaletteList.forceActiveFocus();
                    return;
                }

                // Forward Up/Down keys directly to runnerGrid when on search page
                if (view.currentIndex === 1 && (event.key === Qt.Key_Up || event.key === Qt.Key_Down)) {
                    event.accepted = true;
                    runnerGrid.focus = true;

                    if (event.key === Qt.Key_Down) {
                        if (!runnerGrid.focus || runnerGrid.currentIndex === -1) {
                            runnerGrid.tryActivate(0, 0);
                        } else {
                            var currentGrid = runnerGrid.subGridAt(0);
                            if (currentGrid) {
                                currentGrid.forceActiveFocus();
                                currentGrid.keyNavDown();
                            }
                        }
                    } else if (event.key === Qt.Key_Up) {
                        var lastGridIndex = runnerGrid.count - 1;
                        if (lastGridIndex >= 0) {
                            var lastGrid = runnerGrid.subGridAt(lastGridIndex);
                            if (lastGrid && lastGrid.count > 0) {
                                lastGrid.tryActivate(lastGrid.lastRow(), 0);
                                lastGrid.focus = true;
                            }
                        }
                    }
                    return;
                }

                if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                    event.accepted = true;
                    if (view.currentIndex === 1) {
                        // For search results page
                        runnerGrid.focus = true;
                        runnerGrid.tryActivate(0, 0);
                    } else {
                        // For other pages
                        view.currentItem.forceActiveFocus();
                        view.currentItem.tryActivate(0, 0);
                    }
                }

                
            }
            Keys.onReturnPressed: {
                if (root.searching && searchField.text.startsWith('>') && Plasmoid.configuration.enableShellRunner) {
                    var cmd = searchField.text.slice(1).trim();
                    if (cmd.length > 0) {
                        executable.exec(cmd);
                        root.toggle();
                        return;
                    }
                }
                if (root.searching && searchField.text.startsWith('/')) {
                    // Calculator result: copy to clipboard
                    if (commandPaletteContainer.calcResult !== "") {
                        executable.exec("printf '%s' '" + commandPaletteContainer.calcResult + "' | xclip -selection clipboard 2>/dev/null || printf '%s' '" + commandPaletteContainer.calcResult + "' | xsel --clipboard --input 2>/dev/null");
                        root.toggle();
                        return;
                    }
                    // Normal command execution
                    var query = searchField.text.slice(1).toLowerCase().trim();
                    var matched = rootItem.paletteCommands.filter(function(c) {
                        return query === "" || c.name.startsWith(query);
                    });
                    if (matched.length > 0 && matched[0].cmd !== "") {
                        executable.exec(matched[0].cmd);
                        root.toggle();
                    }
                    return;
                }
                if (view.currentIndex === 1) {
                    // On search results page, activate the first available item
                    runnerGrid.focus = true;

                    // Find the first grid with items and activate its first item
                    for (var i = 0; i < runnerGrid.count; i++) {
                        var grid = runnerGrid.subGridAt(i);
                        if (grid && grid.count > 0) {
                            grid.currentIndex = 0;
                            grid.focus = true;
                            grid.itemActivated(0, "", null);
                       
                            if ("trigger" in grid.model) {
                                //console.log("Calling grid.model.trigger(0)");
                                grid.model.trigger(0, "", null);
                                root.toggle();
                            }
                            return;
                        }
                    }
                } else {
                    // Original logic for other pages
                    for (var i = 0; i < runnerGrid.count; i++) {
                        var grid = runnerGrid.subGridAt(i)
                        if (grid && grid.count > 0) {
                            grid.currentIndex = 0
                            grid.focus = true
                            grid.itemActivated(0, "", null)
                            return
                        }
                    }
                }
            }
            function backspace() {
                if (!root.visible) {
                    return;
                }
                focus = true;
                text = text.slice(0, -1);
            }

            function appendText(newText) {
                if (!root.visible) {
                    return;
                }
                focus = true;
                text = text + newText;
            }

            Kirigami.Icon {
                source: root.searching && searchField.text.startsWith('>')
                        ? 'utilities-terminal'
                        : root.searching && searchField.text.startsWith('/')
                        ? 'run-build'
                        : 'search'
                anchors {
                    left: searchField.left
                    verticalCenter: searchField.verticalCenter
                    leftMargin: Kirigami.Units.smallSpacing * 2
                }
                height: Kirigami.Units.iconSizes.small
                width: height

                Behavior on opacity { NumberAnimation { duration: 120 } }
            }
        }

        // ── Volet « Appareil mobile » (KDE Connect), fichier KdeConnectPanel.qml ──
        KdeConnectPanel {
            id: kdeConnectPanel
            menuWindow: root
        }

        // ── Infobulle partagée (tuiles « Tout », documents, grilles, épinglage) ──
        // Fenestra : dans CE dialogue, les PC3.ToolTip (Popup) ancrés dans la page
        // défilante sont rendus décalés vers le haut — le décalage suit le défilement.
        // On dessine donc l'infobulle SOI-MÊME : un simple cadre au NIVEAU DE LA
        // FENÊTRE, position calculée avec mapToItem au moment du survol. Aucun Popup
        // n'est impliqué, donc aucun décalage possible.
        function showTileTip(item, text) {
            if (!item || !text || text.length === 0) return;
            tileTipAnchor.source = item;
            tileTipAnchor.text = text;
            // taille calée sur la police par défaut du thème (suit le DPI) : texte en
            // defaultFont + marges d'un gridUnit, comme le ToolTip Plasma d'origine
            var w = Math.ceil(tipLabel.implicitWidth) + Kirigami.Units.gridUnit;
            var h = Math.ceil(tipLabel.implicitHeight) + Kirigami.Units.smallSpacing * 2;
            tileTipAnchor.width = w;
            tileTipAnchor.height = h;
            var p = item.mapToItem(rootItem, item.width / 2, 0);
            tileTipAnchor.x = Math.max(4, Math.min(Math.round(p.x - w / 2), rootItem.width - w - 4));
            var y = Math.round(p.y - h - 6);
            if (y < 4) y = Math.round(p.y + item.height + 6);   // pas de place au-dessus : en dessous
            tileTipAnchor.y = y;
            // Déjà visible (ou en cours de disparition) : on reste affiché et on file
            // vers le nouvel élément (Behaviour sur x/y) — ni délai, ni animation de
            // sortie, sinon les deux animations se battent quand on passe d'un fichier
            // à l'autre dans la même section.
            if (tileTipAnchor.opacity > 0) {
                tileTipAnchor.shown = true;
                return;
            }
            tileTipDelay.restart();            // sinon délai d'apparition
        }

        function hideTileTip(item) {
            // un autre élément a déjà pris la main : ne pas éteindre son infobulle
            if (item && tileTipAnchor.source && tileTipAnchor.source !== item) return;
            tileTipAnchor.source = null;
            tileTipDelay.stop();
            tileTipAnchor.shown = false;   // disparition animée (visible suit l'opacité)
        }

        Timer {
            id: tileTipDelay
            interval: 400
            onTriggered: if (tileTipAnchor.source) tileTipAnchor.shown = true
        }

        Item {
            id: tileTipAnchor
            z: 1000
            // Fenestra : animation « Windows 11 / Fluent 2 » de l'infobulle :
            //  - apparition : fondu + glissement de 4 px vers le haut, 200 ms,
            //    courbe « décélération » (facile au début, freinée à la fin) ;
            //  - disparition : fondu pur, 100 ms, courbe « accélération ».
            property bool shown: false
            opacity: 0
            visible: opacity > 0
            transform: Translate { id: tipShift; y: 4 }

            states: [
                State {
                    name: "shown"
                    when: tileTipAnchor.shown
                    PropertyChanges { target: tileTipAnchor; opacity: 1 }
                    PropertyChanges { target: tipShift; y: 0 }
                },
                State {
                    name: "hidden"
                    when: !tileTipAnchor.shown
                    PropertyChanges { target: tileTipAnchor; opacity: 0 }
                    PropertyChanges { target: tipShift; y: 4 }
                }
            ]

            transitions: [
                Transition {
                    to: "shown"
                    // opacité et glissement en PARALLÈLE (200 ms au total) : une
                    // animation plus courte est moins souvent interrompue quand
                    // la souris passe d'un fichier à l'autre.
                    NumberAnimation {
                        properties: "opacity,y"
                        duration: 200
                        easing.type: Easing.OutCubic
                    }
                },
                Transition {
                    to: "hidden"
                    NumberAnimation {
                        properties: "opacity"
                        duration: 100
                        easing.type: Easing.InCubic
                    }
                }
            ]

            // glissement souple vers le nouvel élément quand l'infobulle est déjà
            // affichée (plus de saut brutal de position entre deux fichiers)
            Behavior on x {
                NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
            }
            Behavior on y {
                NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
            }

            property string text: ""
            property var source: null

            Rectangle {
                anchors.fill: parent
                radius: 5
                color: Kirigami.Theme.backgroundColor
                border.width: 1
                border.color: root.colorWithAlpha(Kirigami.Theme.highlightColor, 0.6)
            }
            PC3.Label {
                id: tipLabel
                anchors.centerIn: parent
                text: tileTipAnchor.text
                color: Kirigami.Theme.textColor
                // police par défaut du thème : suit le DPI, même taille que les
                // infobulles natives de Plasma
                font.pointSize: Kirigami.Theme.defaultFont.pointSize
                textFormat: Text.PlainText
            }
        }

        // ── Bouton KDE Connect à droite de la recherche (action à brancher plus tard) ──
        Item {
            id: kdeConnectButton
            visible: Plasmoid.configuration.kdeConnectShow   // Fenestra : masque le bouton selon préférence
            anchors {
                top: searchField.top
                right: parent.right
                rightMargin: rootItem.margeCote   // Fenestra : bouton aligné sur la marge réduite (était décalé de 10 px vers la droite)
            }
            height: searchField.height
            width: height
            Accessible.role: Accessible.Button
            Accessible.name: "KDE Connect"

            Rectangle {
                anchors.fill: parent
                radius: 5
                color: (Kirigami.Theme.textColor.hslLightness > 0.5 ? "#26ffffff" : "#80ffffff")
                border.width: 1
                border.color: (Kirigami.Theme.textColor.hslLightness > 0.5 ? "#1affffff" : "#14000000")
                opacity: (kdeConnectMouse.containsMouse || kdeConnectPanel.visible) ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 100 } }
            }

            Kirigami.Icon {
                anchors.centerIn: parent
                width: Kirigami.Units.iconSizes.smallMedium
                height: width
                source: Qt.resolvedUrl("../icons/status/kdeconnect.svg")
            }

            MouseArea {
                id: kdeConnectMouse
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton
                onClicked: {
                    rootItem.hideTileTip();      // Fenestra : ferme l'infobulle dès l'ouverture du volet
                    root.basculerVolet();        // Fenestra : ordre du recentrage
                }

                // Fenestra : infobulle « KDE Connect » via l'infobulle PARTAGÉE
                // (rootItem.showTileTip), comme les tuiles et les documents —
                // les PC3.ToolTip attachés à ce PlasmaCore.Dialog étaient
                // rendus décalés (positionnés en haut de la fenêtre).
                onContainsMouseChanged: {
                    if (typeof rootItem === "undefined" || !rootItem.showTileTip) return;
                    if (containsMouse) rootItem.showTileTip(kdeConnectButton, i18n("KDE Connect"));
                    else rootItem.hideTileTip(kdeConnectButton);
                }
            }
        }

        // ── Quick Actions Bar ────────────────────────────────────────────────
        // Shows contextual single-click actions when search is idle; slides away while searching.
        Item {
            id: quickActionsBar
            anchors.top: searchField.bottom
            anchors.topMargin: Kirigami.Units.smallSpacing
            anchors.left: parent.left
            anchors.leftMargin: rootItem.margeCote
            anchors.right: parent.right
            anchors.rightMargin: rootItem.margeCote
            clip: true
            height: (root.searching || !Plasmoid.configuration.showQuickActions) ? 0 : qaRow.implicitHeight + Kirigami.Units.smallSpacing

            Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

            Row {
                id: qaRow
                anchors.verticalCenter: parent.verticalCenter
                spacing: Kirigami.Units.smallSpacing / 2

                Repeater {
                    model: [
                        { icon: "spectacle",           tip: i18n("Screenshot"),     cmd: "spectacle --gui" },
                        { icon: "system-lock-screen",  tip: i18n("Lock Screen"),    cmd: "loginctl lock-session" },
                        { icon: "utilities-terminal",  tip: i18n("Open Terminal"),  cmd: "konsole" },
                        { icon: "system-file-manager", tip: i18n("Open Files"),     cmd: "dolphin" },
                        { icon: "accessories-calculator", tip: i18n("Calculator"),  cmd: "kcalc" },
                        { icon: "preferences-system",  tip: i18n("System Settings"), cmd: "systemsettings" }
                    ]

                    delegate: PC3.ToolButton {
                        id: qaButton
                        icon.name: modelData.icon
                        display: AbstractButton.IconOnly
                        opacity: hovered ? 1.0 : 0.55
                        Behavior on opacity { NumberAnimation { duration: 100 } }
                        onClicked: {
                            executable.exec(modelData.cmd);
                            root.toggle();
                        }
                        // Fenestra : infobulle via l'infobulle PARTAGÉE (rootItem.showTileTip),
                        // comme les tuiles / documents / bouton KDE Connect — un PC3.ToolTip
                        // attaché dans ce PlasmaCore.Dialog était rendu décalé.
                        onHoveredChanged: {
                            if (typeof rootItem === "undefined" || !rootItem.showTileTip) return;
                            if (hovered) rootItem.showTileTip(qaButton, modelData.tip);
                            else rootItem.hideTileTip(qaButton);
                        }
                    }
                }
            }
        }

        // ── Trait sous la barre de recherche ────────────────────────────────
        Rectangle {
            id: searchSeparator
            // marges du cadre de la fenêtre, mesurées une fois le popup affiché
            property real extLeft: 0
            property real extRight: 0
            function updateExtension() {
                var w = parent.Window.window;
                if (!w) return;
                var p = parent.mapToItem(null, 0, 0);
                extLeft = Math.max(0, p.x);
                extRight = Math.max(0, w.width - p.x - parent.width);
            }
            Component.onCompleted: Qt.callLater(updateExtension)
            Connections {
                target: root
                function onVisibleChanged() {
                    if (root.visible) Qt.callLater(searchSeparator.updateExtension);
                }
            }
            anchors {
                top: quickActionsBar.bottom
                topMargin: Math.round(Kirigami.Units.gridUnit * 0.6)
                left: parent.left
                leftMargin: -extLeft
                right: parent.right
                rightMargin: -extRight
            }
            height: 1
            color: colorWithAlpha(Kirigami.Theme.textColor, 0.15)
        }

        SwipeView {
            id: view

            interactive: false
            currentIndex: 0
            clip: true
            // Quand le sélecteur de lettres est ouvert, on masque la liste des applications
            // derrière lui : le fond du dialogue Plasma apparaît alors à travers le sélecteur
            // transparent, ce qui garantit un rendu identique au thème (pas de fond blanc).
            opacity: letterPicker.visible ? 0.0 : 1.0
            Behavior on opacity { NumberAnimation { duration: 80 } }

            anchors {
                top: searchSeparator.bottom
                topMargin: Kirigami.Units.smallSpacing + 10
                left: parent.left
                leftMargin: rootItem.margeCote
                right: parent.right
                rightMargin: -searchSeparator.extRight
            }
            onCurrentIndexChanged: {
                globalFavoritesGrid.currentIndex = -1;
                documentsGrid.currentIndex = -1;
            }

            width: rootItem.widthComputed
            // Fenestra : la page ne fait jamais plus que l'espace restant (viewWanted est déjà
            // borné par l'écran utile) — pas de plancher qui forcerait un débordement.
            height: Math.max(1, Math.min(rootItem.viewWanted, rootItem.height - view.y - footer.height))

            // PAGE 1 — page unique : épinglés, recommandations, « Tout »
            Flickable {
                id: mainFlick
                width: view.width
                height: view.height
                contentWidth: mainColumn.width
                contentHeight: mainColumn.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                flickableDirection: Flickable.VerticalFlick
                onContentYChanged: rootItem.noteScrolling()

                PC3.ScrollBar.vertical: PC3.ScrollBar {}

                function tryActivate(row, col) {
                    if (!rootItem.pinnedCollapsed)
                        globalFavoritesGrid.tryActivate(row, col);
                    else if (documentsGrid.visible)
                        documentsGrid.tryActivate(0, 0);
                    else
                        allAppsGrid.tryActivate(0, 0);
                }

                function scrollTo(y) {
                    var maxY = Math.max(0, contentHeight - height);
                    scrollAnim.stop();
                    scrollAnim.to = Math.max(0, Math.min(y, maxY));
                    scrollAnim.start();
                }

                function ensureVisible(top, bottom) {
                    var pad = Kirigami.Units.largeSpacing;
                    var maxY = Math.max(0, contentHeight - height);
                    if (top - pad < contentY)
                        contentY = Math.max(0, top - pad);
                    else if (bottom + pad > contentY + height)
                        contentY = Math.min(maxY, bottom + pad - height);
                }

                NumberAnimation {
                    id: scrollAnim
                    target: mainFlick
                    property: "contentY"
                    duration: 220
                    easing.type: Easing.OutCubic
                }

                Column {
                id: mainColumn
                width: rootItem.width - rootItem.margeCote * 2
                spacing: Kirigami.Units.largeSpacing * 2

                RowLayout {
                    id: topRow
                    x: rootItem.sectionInset
                    // + largeSpacing + 5 : compense le padding interne du bouton (comme Catégories)
                    width: parent.width - rootItem.sectionInset * 2 + Kirigami.Units.largeSpacing + 5

                    PlasmaExtras.Heading {
                        color: colorWithAlpha(Kirigami.Theme.textColor, 0.8)
                        level: 5
                        text: i18n("Pinned")
                        font.weight: Font.Bold
                        Layout.alignment: Qt.AlignVCenter
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    SectionButton {
                        id: butttonActionAllApps
                        flat: false
                        iconName: rootItem.pinnedCollapsed ? "go-down" : "go-up"
                        text: rootItem.pinnedCollapsed ? i18n("Show more") : i18n("Show less")
                        buttonHeight: 25
                        onClicked: rootItem.pinnedCollapsed = !rootItem.pinnedCollapsed
                    }
                }

                ItemGridView {
                    id: globalFavoritesGrid
                    whiteHighlight: true // surlignement blanc 50 %
                    pinnedGrid: true
                    visible: true
                    clip: true   // coupe net les rangées au-delà du repli
                    width: parent.width
                    height: root.cellSizeHeight * Math.max(1, Math.min(rootItem.pinnedCollapsed ? rootItem.pinnedCollapsedRows : Plasmoid.configuration.numberRows, Math.ceil(count / root.colonnesAuto)))
                    itemColumns: 1
                    dragEnabled: true
                    dropEnabled: true
                    cellWidth: parent.width / root.colonnesAuto
                    cellHeight: root.cellSizeHeight
                    iconSize: root.iconSize
                    labels2lines: Plasmoid.configuration.labels2lines
                    onWheelUnhandled: (delta) => {
                        var maxY = Math.max(0, mainFlick.contentHeight - mainFlick.height);
                        mainFlick.contentY = Math.max(0, Math.min(maxY, mainFlick.contentY - delta));
                    }
                    onKeyNavUp: {
                        if (rootItem.pinnedCurrentPage > 0) {
                            rootItem.pinnedCurrentPage--;
                            globalFavoritesGrid.tryActivate(Plasmoid.configuration.numberRows - 1, 0);
                        } else {
                            globalFavoritesGrid.focus = false;
                            searchField.focus = true;
                        }
                    }
                    onKeyNavDown: {
                        if (rootItem.pinnedCurrentPage < rootItem.pinnedTotalPages - 1) {
                            rootItem.pinnedCurrentPage++;
                            globalFavoritesGrid.tryActivate(0, 0);
                        } else {
                            globalFavoritesGrid.focus = false;
                            documentsGrid.tryActivate(0, 0);
                        }
                    }
                    onKeyNavLeft: {
                        if (rootItem.pinnedCurrentPage > 0) {
                            rootItem.pinnedCurrentPage--;
                            globalFavoritesGrid.tryActivate(0, root.colonnesAuto - 1);
                        }
                    }
                    onKeyNavRight: {
                        if (rootItem.pinnedCurrentPage < rootItem.pinnedTotalPages - 1) {
                            rootItem.pinnedCurrentPage++;
                            globalFavoritesGrid.tryActivate(0, 0);
                        }
                    }
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Tab) {
                            event.accepted = true;
                            searchField.focus = true;
                            globalFavoritesGrid.focus = false;
                        } else if (event.key === Qt.Key_PageDown) {
                            event.accepted = true;
                            if (rootItem.pinnedCurrentPage < rootItem.pinnedTotalPages - 1) {
                                rootItem.pinnedCurrentPage++;
                                globalFavoritesGrid.tryActivate(0, 0);
                            }
                        } else if (event.key === Qt.Key_PageUp) {
                            event.accepted = true;
                            if (rootItem.pinnedCurrentPage > 0) {
                                rootItem.pinnedCurrentPage--;
                                globalFavoritesGrid.tryActivate(0, 0);
                            }
                        } else if (event.key === Qt.Key_Home) {
                            event.accepted = true;
                            rootItem.pinnedCurrentPage = 0;
                            globalFavoritesGrid.tryActivate(0, 0);
                        } else if (event.key === Qt.Key_End) {
                            event.accepted = true;
                            rootItem.pinnedCurrentPage = rootItem.pinnedTotalPages - 1;
                            globalFavoritesGrid.tryActivate(0, 0);
                        }
                    }
                }

                // Page indicator dots for pinned apps pagination
                Item {
                    visible: !rootItem.pinnedCollapsed
                    width: parent.width
                    height: Kirigami.Units.gridUnit

                    Row {
                        anchors.centerIn: parent
                        spacing: Kirigami.Units.smallSpacing * 2
                        visible: rootItem.pinnedTotalPages > 1

                        Repeater {
                            model: rootItem.pinnedTotalPages
                            delegate: Item {
                                readonly property bool isCurrent: rootItem.pinnedCurrentPage === index
                                width: isCurrent ? 20 : 8
                                height: 8
                                anchors.verticalCenter: parent.verticalCenter

                                Behavior on width {
                                    NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: height / 2
                                    color: isCurrent
                                           ? Kirigami.Theme.highlightColor
                                           : root.colorWithAlpha(Kirigami.Theme.textColor, 0.3)

                                    Behavior on color {
                                        ColorAnimation { duration: 150 }
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: rootItem.pinnedCurrentPage = index
                                }
                            }
                        }
                    }
                }

                // Fixed-height container so the menu never resizes when docs/recent-apps are toggled
                Item {
                    id: docsContainer
                    x: rootItem.sectionInset
                    width: parent.width - rootItem.sectionInset * 2

                    readonly property int recentAppsStripHeight: Plasmoid.configuration.showRecentApps
                        ? Kirigami.Units.iconSizes.medium + Kirigami.Units.largeSpacing * 3
                        : 0

                    height: recentAppsStripHeight
                          + butttonActionAllApps.implicitHeight
                          + Kirigami.Units.largeSpacing * 2
                          + (Plasmoid.configuration.showRecentDocs ? (docsIconSize + Kirigami.Units.largeSpacing * 2) * 3 : 0)

                    // Recently opened apps — horizontal icon strip
                    Item {
                        id: recentAppsStrip
                        width: parent.width
                        height: docsContainer.recentAppsStripHeight
                        visible: Plasmoid.configuration.showRecentApps

                        // Smart context header
                        Row {
                            id: recentAppsHeader
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Kirigami.Units.smallSpacing / 2

                            Kirigami.Icon {
                                id: recentAppsHeaderIcon
                                source: 'view-history'
                                anchors.verticalCenter: parent.verticalCenter
                                implicitHeight: Kirigami.Units.iconSizes.smallMedium
                                implicitWidth: Kirigami.Units.iconSizes.smallMedium
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: rootItem.contextLabel
                                color: root.colorWithAlpha(Kirigami.Theme.textColor, 0.55)
                                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.78
                            }
                        }

                        ListView {
                            id: recentAppsListView
                            anchors.left: recentAppsHeader.right
                            anchors.leftMargin: Kirigami.Units.smallSpacing * 2
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            orientation: ListView.Horizontal
                            interactive: false
                            spacing: Kirigami.Units.smallSpacing
                            clip: true

                            delegate: Item {
                                id: recentAppItem
                                width: Kirigami.Units.iconSizes.medium + Kirigami.Units.gridUnit * 2
                                height: recentAppsListView.height

                                // Fenestra : infobulle (nom tronqué) via l'infobulle PARTAGÉE
                                // (rootItem.showTileTip) — un PC3.ToolTip attaché ici était rendu décalé.
                                readonly property bool tipHover: recentAppHover.containsMouse && recentAppLabel.truncated
                                onTipHoverChanged: {
                                    if (typeof rootItem === "undefined" || !rootItem.showTileTip) return;
                                    if (tipHover) rootItem.showTileTip(recentAppItem, model.display || "");
                                    else rootItem.hideTileTip(recentAppItem);
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: -Kirigami.Units.smallSpacing / 2
                                    radius: Kirigami.Units.smallSpacing + 2
                                    color: Kirigami.Theme.highlightColor
                                    opacity: recentAppHover.containsMouse ? 0.12 : 0.0
                                    Behavior on opacity { NumberAnimation { duration: 100 } }
                                }

                                Column {
                                    anchors.centerIn: parent
                                    spacing: Kirigami.Units.smallSpacing / 2

                                    Kirigami.Icon {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        source: model.decoration || ""
                                        width: Kirigami.Units.iconSizes.smallMedium
                                        height: width
                                    }

                                    Text {
                                        id: recentAppLabel
                                        width: recentAppItem.width - Kirigami.Units.smallSpacing * 2
                                        text: model.display || ""
                                        color: Kirigami.Theme.textColor
                                        opacity: 0.75
                                        font.pointSize: Math.max(6, Kirigami.Theme.defaultFont.pointSize * 0.77)
                                        horizontalAlignment: Text.AlignHCenter
                                        elide: Text.ElideRight
                                        maximumLineCount: 1
                                    }
                                }

                                MouseArea {
                                    id: recentAppHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (recentAppsListView.model && "trigger" in recentAppsListView.model) {
                                            recentAppsListView.model.trigger(index, "", null);
                                            root.toggle();
                                        }
                                    }
                                }
                            }
                        }
                    }

                    RowLayout {
                        id: docsHeaderRow
                        // + largeSpacing + 5 : compense le padding interne du bouton (comme Catégories)
                        width: parent.width + Kirigami.Units.largeSpacing + 5
                        height: butttonActionAllApps.implicitHeight
                        y: docsContainer.recentAppsStripHeight
                        opacity: Plasmoid.configuration.showRecentDocs ? 1.0 : 0.0
                        enabled: Plasmoid.configuration.showRecentDocs

                        Kirigami.Icon {
                            source: 'tag-recents'
                            implicitHeight: Kirigami.Units.iconSizes.smallMedium
                            implicitWidth: Kirigami.Units.iconSizes.smallMedium
                        }

                        PlasmaExtras.Heading {
                            color: colorWithAlpha(Kirigami.Theme.textColor, 0.8)
                            level: 5
                            text: i18n("Recommended")
                            Layout.leftMargin: Kirigami.Units.smallSpacing
                            font.weight: Font.Bold
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        SectionButton {
                            id: butttonActionRecentMore
                            flat: false
                            iconName: "go-next"
                            text: i18n("Show all")
                            buttonHeight: 25
                            onClicked: view.currentIndex = 2
                        }
                    }

                    ItemGridView {
                        id: documentsGrid
                        whiteHighlight: true // surlignement blanc 50 %
                        recentDocsMode: true
                        y: docsContainer.recentAppsStripHeight + butttonActionAllApps.implicitHeight + Kirigami.Units.largeSpacing * 2
                        x: -rootItem.listIconPad
                        width: parent.width + rootItem.listIconPad * 2
                        height: (docsIconSize + Kirigami.Units.largeSpacing * 2) * 3
                        itemColumns: 2
                        dragEnabled: true
                        dropEnabled: true
                        cellWidth: parent.width * 0.48
                        cellHeight: docsIconSize + Kirigami.Units.largeSpacing * 2
                        iconSize: docsIconSize
                        onWheelUnhandled: (delta) => {
                            var maxY = Math.max(0, mainFlick.contentHeight - mainFlick.height);
                            mainFlick.contentY = Math.max(0, Math.min(maxY, mainFlick.contentY - delta));
                        }
                        clip: true
                        visible: Plasmoid.configuration.showRecentDocs && view.currentIndex === 0
                        onKeyNavUp: {
                            if (rootItem.pinnedCollapsed) {
                                searchField.focus = true;
                            } else {
                                globalFavoritesGrid.tryActivate(0, 0);
                            }
                            documentsGrid.focus = false;
                        }
                        onKeyNavDown: {
                            documentsGrid.focus = false;
                            allAppsGrid.tryActivate(0, 0);
                        }
                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Tab) {
                                event.accepted = true;
                                documentsGrid.focus = false;
                                footerContent.forceActiveFocus();
                            }
                        }
                    }

                    // Fenestra : espace réservé quand la section « Recommandations » est vide
                    // (aucun document récent) — plus parlant qu'une zone blanche.
                    Item {
                        id: docsPlaceholder
                        visible: Plasmoid.configuration.showRecentDocs && documentsGrid.count === 0
                        x: documentsGrid.x
                        y: documentsGrid.y
                        width: documentsGrid.width
                        height: documentsGrid.height

                        Column {
                            anchors.centerIn: parent
                            spacing: Kirigami.Units.largeSpacing

                            Kirigami.Icon {
                                anchors.horizontalCenter: parent.horizontalCenter
                                source: "document-open-recent"
                                implicitWidth: Kirigami.Units.iconSizes.large
                                implicitHeight: Kirigami.Units.iconSizes.large
                                opacity: 0.4
                            }

                            PC3.Label {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: i18n("No recently accessed files yet")
                                color: root.colorWithAlpha(Kirigami.Theme.textColor, 0.55)
                                font.pointSize: Kirigami.Theme.defaultFont.pointSize
                            }
                        }
                    }
                }
                // ── Plugin UI Sections ──────────────────────────────────────
                Column {
                    id: pluginSectionsColumn
                    width: parent.width
                    spacing: Kirigami.Units.largeSpacing
                    visible: pluginSectionsRepeater.count > 0

                    Repeater {
                        id: pluginSectionsRepeater
                        model: PluginSystem.uiSections()

                        delegate: Item {
                            width: pluginSectionsColumn.width
                            height: sectionLoader.implicitHeight + Kirigami.Units.largeSpacing

                            // Section header
                            Row {
                                id: sectionHeader
                                spacing: Kirigami.Units.smallSpacing

                                Kirigami.Icon {
                                    source: "plugins"
                                    implicitWidth: Kirigami.Units.iconSizes.smallMedium
                                    implicitHeight: Kirigami.Units.iconSizes.smallMedium
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                PlasmaExtras.Heading {
                                    level: 5
                                    text: modelData.name
                                    color: root.colorWithAlpha(Kirigami.Theme.textColor, 0.8)
                                    font.weight: Font.Bold
                                }
                            }

                            Loader {
                                id: sectionLoader
                                anchors.top: sectionHeader.bottom
                                anchors.topMargin: Kirigami.Units.smallSpacing
                                width: parent.width
                                sourceComponent: modelData.component
                            }
                        }
                    }
                }

                // ── Tout (ex-page « Toutes les applications ») ──────────────
                RowLayout {
                    id: allAppsHeader
                    x: rootItem.sectionInset
                    // en mode Catégories : on suit la largeur réellement occupée par les tuiles
                    // (Math.floor dans CategoryTiles.qml laisse quelques pixels de côté à droite)
                    width: Plasmoid.configuration.allAppsViewMode === 2
                           ? (allAppsCategoryGrid.tileWidth * allAppsCategoryGrid.columnsCount
                              + allAppsCategoryGrid.gap * (allAppsCategoryGrid.columnsCount - 1)
                              + Kirigami.Units.largeSpacing + 5) // compense le padding du bouton + ajustement fin
                           : (parent.width - rootItem.sectionInset * 2)
                    height: butttonActionAllApps.implicitHeight

                    PlasmaExtras.Heading {
                        color: colorWithAlpha(Kirigami.Theme.textColor, 0.8)
                        level: 5
                        text: i18n("All")
                        font.weight: Font.Bold
                    }

                    Item { Layout.fillWidth: true }

                    SectionButton {
                        id: viewModeButton
                        iconName: "go-down"
                        text: i18n("View: %1", [i18n("List"), i18n("Grid"), i18n("Categories")][Plasmoid.configuration.allAppsViewMode] || "")
                        onClicked: {
                            if (viewModePopup.visible) viewModePopup.visible = false;
                            else viewModePopup.openFor(viewModeButton);
                        }
                    }
                }

                Item {
                    id: allAppsGridContainer
                    readonly property int listInset: Math.max(0, rootItem.sectionInset - rootItem.listIconPad)
                    readonly property bool gridMode: Plasmoid.configuration.allAppsViewMode === 1
                    x: gridMode ? 0 : listInset
                    width: parent.width - (gridMode ? 0 : listInset) * 2
                    height: allAppsGrid.height
                    visible: Plasmoid.configuration.allAppsViewMode !== 2

                    // la molette doit faire défiler la page, pas la grille (qui capte les événements)
                    MouseArea {
                        anchors.fill: parent
                        z: 10
                        acceptedButtons: Qt.NoButton
                        onWheel: wheel => {
                            var d = wheel.pixelDelta.y !== 0 ? wheel.pixelDelta.y : wheel.angleDelta.y / 2;
                            var maxY = Math.max(0, mainFlick.contentHeight - mainFlick.height);
                            scrollAnim.stop();
                            mainFlick.contentY = Math.max(0, Math.min(maxY, mainFlick.contentY - d));
                            wheel.accepted = true;
                        }
                    }

                    ItemGridView {
                        id: allAppsGrid
                        whiteHighlight: true // surlignement blanc 50 %
                        width: parent.width
                        readonly property int columnsCount: cellWidth > 0 ? Math.max(1, Math.floor(width / cellWidth)) : 1
                        // la grille ne défile plus : elle prend toute sa hauteur, c'est la page qui défile
                        height: Math.max(1, Math.ceil(allAppsComboModel.count / columnsCount)) * cellHeight
                        itemColumns: Plasmoid.configuration.allAppsViewMode === 1 ? 1 : 2
                        labels2lines: Plasmoid.configuration.allAppsViewMode === 1 && Plasmoid.configuration.labels2lines
                        dragEnabled: true
                        dropEnabled: false
                        verticalScrollBarPolicy: PC3.ScrollBar.AlwaysOff
                        cellWidth: Plasmoid.configuration.allAppsViewMode === 1
                                   ? Math.floor(width / Math.max(1, root.colonnesAuto))
                                   : width - Kirigami.Units.gridUnit * 2
                        cellHeight: Plasmoid.configuration.allAppsViewMode === 1
                                    ? root.cellSizeHeight
                                    : root.iconSize + Kirigami.Units.gridUnit + Kirigami.Units.largeSpacing
                        iconSize: root.iconSize
                        clip: true
                        onKeyNavUp: {
                            allAppsGrid.focus = false;
                            if (documentsGrid.visible)
                                documentsGrid.tryActivate(documentsGrid.lastRow(), 0);
                            else if (rootItem.pinnedCollapsed)
                                searchField.focus = true;
                            else
                                globalFavoritesGrid.tryActivate(0, 0);
                        }
                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Tab) {
                                event.accepted = true;
                                searchField.focus = true;
                                allAppsGrid.focus = false;
                            }
                        }
                    }
                }

                CategoryTiles {
                    id: allAppsCategoryGrid
                    visible: Plasmoid.configuration.allAppsViewMode === 2
                    x: rootItem.sectionInset
                    width: parent.width - rootItem.sectionInset * 2
                    flyoutOpen: categoryFlyout.visible
                    onOpenCategory: (row, title, sx, sy) => categoryFlyout.openFor(row, title, sx, sy)
                }

                Item { width: 1; height: Kirigami.Units.largeSpacing }
                } // fin mainColumn

                // --- MASQUE MOLETTE : intercepte la molette au-dessus d'Épinglé + Recommandations
                // avant que gridView (en dessous) ne l'absorbe nativement. Aucune MouseArea ici :
                // clics, survol et glisser-déposer des icônes passent normalement au travers.
                Item {
                    id: wheelMask
                    x: 0
                    y: 0
                    width: mainColumn.width
                    height: docsContainer.y + docsContainer.height
                    z: 999

                    WheelHandler {
                        target: null
                        acceptedDevices: PointerDevice.AllDevices
                        onWheel: event => {
                            event.accepted = true;
                            var maxY = Math.max(0, mainFlick.contentHeight - mainFlick.height);
                            var pixels = (event.angleDelta.y / 120) * Kirigami.Units.gridUnit * 3;
                            mainFlick.contentY = Math.max(0, Math.min(maxY, mainFlick.contentY - pixels));
                        }
                    }
                }

                // garde la ligne sélectionnée au clavier visible dans la page qui défile
                Connections {
                    target: allAppsGrid
                    function onCurrentIndexChanged() {
                        if (allAppsGrid.currentIndex < 0 || !rootItem.keyNavRecently()) return;
                        var row = Math.floor(allAppsGrid.currentIndex / allAppsGrid.columnsCount);
                        var top = allAppsGridContainer.y + row * allAppsGrid.cellHeight;
                        mainFlick.ensureVisible(top, top + allAppsGrid.cellHeight);
                    }
                }
            // la page suit aussi la sélection clavier quand on remonte vers les recommandations / les épinglés
                Connections {
                    target: globalFavoritesGrid
                    function onCurrentIndexChanged() {
                        if (globalFavoritesGrid.currentIndex < 0 || !rootItem.keyNavRecently()) return;
                        mainFlick.ensureVisible(0, globalFavoritesGrid.y + globalFavoritesGrid.height);
                    }
                }
                Connections {
                    target: documentsGrid
                    function onCurrentIndexChanged() {
                        if (documentsGrid.currentIndex < 0 || !rootItem.keyNavRecently()) return;
                        mainFlick.ensureVisible(docsContainer.y, docsContainer.y + docsContainer.height);
                    }
                }
            } // fin mainFlick


            // PAGE 3 — Search Results
            Item {
                id: searchPage
                width: rootItem.widthComputed
                height: view.height

                function tryActivate(row, col) { runnerGrid.tryActivate(row, col); }

                // ── Filter pills (slide in when searching, hidden in shell/palette mode) ──
                Item {
                    id: filterPillsWrapper
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    clip: true
                    height: (root.searching && !searchField.text.startsWith('>') && !searchField.text.startsWith('/'))
                            ? pillsRow.implicitHeight + Kirigami.Units.smallSpacing * 2
                            : 0

                    Behavior on height {
                        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                    }

                    Row {
                        id: pillsRow
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: Kirigami.Units.smallSpacing
                        spacing: Kirigami.Units.smallSpacing

                        Repeater {
                            model: [
                                { key: "all",      label: i18n("All")      },
                                { key: "apps",     label: i18n("Apps")     },
                                { key: "files",    label: i18n("Files")    },
                                { key: "settings", label: i18n("Settings") },
                                { key: "actions",  label: i18n("Actions")  }
                            ]

                            delegate: Item {
                                id: pillDelegate
                                property bool isActive: kicker.searchRunnerFilter === modelData.key
                                height: Kirigami.Units.gridUnit * 2
                                width: pillText.implicitWidth + Kirigami.Units.gridUnit * 2

                                focus: true
                                activeFocusOnTab: true
                                Accessible.role: Accessible.Button
                                Accessible.name: modelData.label
                                Accessible.checked: isActive

                                function activate() {
                                    kicker.searchRunnerFilter = modelData.key;
                                    var q = searchField.text;
                                    runnerModel.query = "";
                                    runnerModel.query = q;
                                }

                                Keys.onReturnPressed: activate()
                                Keys.onSpacePressed:  activate()

                                // Fill background
                                Rectangle {
                                    anchors.fill: parent
                                    radius: height / 2
                                    color: isActive
                                           ? Kirigami.Theme.highlightColor
                                           : colorWithAlpha(Kirigami.Theme.textColor, 0.08)
                                    border.width: isActive ? 0 : 1
                                    border.color: colorWithAlpha(Kirigami.Theme.textColor, 0.12)
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }

                                // Keyboard focus ring
                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: -2
                                    radius: height / 2 + 2
                                    color: "transparent"
                                    border.width: pillDelegate.activeFocus ? 2 : 0
                                    border.color: Kirigami.Theme.highlightColor
                                    opacity: 0.8
                                    Behavior on border.width { NumberAnimation { duration: 80 } }
                                }

                                Text {
                                    id: pillText
                                    anchors.centerIn: parent
                                    text: modelData.label
                                    color: isActive
                                           ? "white"
                                           : colorWithAlpha(Kirigami.Theme.textColor, 0.75)
                                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.85
                                    font.bold: isActive
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: pillDelegate.activate()
                                }
                            }
                        }
                    }
                }

                // ── Command Palette (visible when text starts with '/') ──────
                Item {
                    id: commandPaletteContainer
                    anchors.top: filterPillsWrapper.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.topMargin: Kirigami.Units.smallSpacing
                    anchors.bottom: parent.bottom
                    visible: root.searching && searchField.text.startsWith('/')

                    property string paletteQuery: searchField.text.startsWith('/')
                                                  ? searchField.text.slice(1).toLowerCase().trim()
                                                  : ""

                    // Inline calculator: /calc 2+2  or /= 2+2
                    property string calcQuery: {
                        var q = paletteQuery.trim();
                        if (q.startsWith("calc ")) return q.slice(5).trim();
                        if (q.startsWith("= "))    return q.slice(2).trim();
                        return "";
                    }

                    property string calcResult: {
                        var expr = calcQuery;
                        if (!expr) return "";
                        try {
                            var r = Function("return (" + expr + ")")();
                            if (r === undefined || (typeof r === "number" && isNaN(r))) return "";
                            return String(r);
                        } catch(e) { return ""; }
                    }

                    // Inline AI: /ai <prompt>
                    property var filteredCmds: {
                        var q = paletteQuery;
                        if (q === "") return rootItem.paletteCommands;
                        // Hide normal commands when in calc mode
                        if (calcQuery !== "") return [];
                        function fuzzyMatch(str, query) {
                            var qi = 0;
                            for (var ci = 0; ci < str.length && qi < query.length; ci++) {
                                if (str[ci] === query[qi]) qi++;
                            }
                            return qi === query.length;
                        }
                        var matches = rootItem.paletteCommands.filter(function(c) {
                            var searchStr = c.name + " " + c.desc.toLowerCase();
                            return c.name.startsWith(q) || fuzzyMatch(searchStr, q);
                        });
                        // Prefix matches first, then fuzzy-only
                        matches.sort(function(a, b) {
                            var aPrefix = a.name.startsWith(q) ? 0 : 1;
                            var bPrefix = b.name.startsWith(q) ? 0 : 1;
                            return aPrefix - bPrefix;
                        });
                        return matches;
                    }

                    // Calculator result card
                    Item {
                        id: calcResultItem
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: commandPaletteContainer.calcResult !== ""
                                ? Kirigami.Units.gridUnit * 3.5 : 0
                        clip: true
                        Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 2
                            radius: Kirigami.Units.smallSpacing
                            color: root.colorWithAlpha(Kirigami.Theme.highlightColor, 0.08)
                            border.width: 1
                            border.color: root.colorWithAlpha(Kirigami.Theme.highlightColor, 0.22)
                        }

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: Kirigami.Units.smallSpacing * 2
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Kirigami.Units.smallSpacing

                            Rectangle {
                                width: Kirigami.Units.gridUnit * 2; height: width
                                radius: width / 2
                                color: root.colorWithAlpha(Kirigami.Theme.highlightColor, 0.18)
                                anchors.verticalCenter: parent.verticalCenter
                                Kirigami.Icon {
                                    source: "accessories-calculator"
                                    width: Kirigami.Units.iconSizes.small; height: width
                                    anchors.centerIn: parent; animated: false
                                }
                            }

                            Column {
                                spacing: 2
                                anchors.verticalCenter: parent.verticalCenter
                                Text {
                                    text: "= " + commandPaletteContainer.calcResult
                                    color: Kirigami.Theme.textColor
                                    font.bold: true
                                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.1
                                }
                                Text {
                                    text: i18n("Enter or click to copy result")
                                    color: root.colorWithAlpha(Kirigami.Theme.textColor, 0.55)
                                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.78
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                executable.exec("printf '%s' '" + commandPaletteContainer.calcResult + "' | xclip -selection clipboard 2>/dev/null || printf '%s' '" + commandPaletteContainer.calcResult + "' | xsel --clipboard --input 2>/dev/null");
                            }
                        }
                    }

                    // AI result card
                    // Hint when nothing narrowed yet
                    Text {
                        visible: commandPaletteContainer.paletteQuery === ""
                        anchors.left: parent.left
                        anchors.leftMargin: Kirigami.Units.smallSpacing * 2
                        anchors.top: calcResultItem.bottom
                        anchors.topMargin: Kirigami.Units.smallSpacing
                        text: i18n("Type a command  ·  ↓ navigate  ·  /calc expr  ·  Enter run")
                        color: root.colorWithAlpha(Kirigami.Theme.textColor, 0.42)
                        font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.82
                    }

                    ListView {
                        id: commandPaletteList
                        anchors.top: calcResultItem.bottom
                        anchors.topMargin: Kirigami.Units.smallSpacing
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        clip: true
                        model: commandPaletteContainer.filteredCmds
                        currentIndex: -1
                        keyNavigationWraps: true

                        Keys.onReturnPressed: {
                            if (currentIndex >= 0 && currentIndex < model.length) {
                                executable.exec(model[currentIndex].cmd);
                                root.toggle();
                            }
                        }
                        Keys.onEscapePressed: {
                            currentIndex = -1;
                            searchField.forceActiveFocus();
                        }

                        highlight: Rectangle {
                            color: root.colorWithAlpha(Kirigami.Theme.highlightColor, 0.18)
                            radius: Kirigami.Units.smallSpacing
                        }
                        highlightMoveDuration: 80

                        delegate: Item {
                            width: commandPaletteList.width
                            height: Kirigami.Units.gridUnit * 3

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 2
                                radius: Kirigami.Units.smallSpacing
                                color: cmdItemHover.containsMouse && commandPaletteList.currentIndex !== index
                                       ? root.colorWithAlpha(Kirigami.Theme.highlightColor, 0.08)
                                       : "transparent"
                                Behavior on color { ColorAnimation { duration: 80 } }
                            }

                            Row {
                                anchors.left: parent.left
                                anchors.leftMargin: Kirigami.Units.smallSpacing * 2
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Kirigami.Units.smallSpacing

                                Rectangle {
                                    width: Kirigami.Units.gridUnit * 2
                                    height: width
                                    radius: width / 2
                                    color: root.colorWithAlpha(Kirigami.Theme.highlightColor, 0.15)
                                    anchors.verticalCenter: parent.verticalCenter

                                    Kirigami.Icon {
                                        source: modelData.icon
                                        width: Kirigami.Units.iconSizes.small
                                        height: width
                                        anchors.centerIn: parent
                                        animated: false
                                    }
                                }

                                Column {
                                    spacing: 1
                                    anchors.verticalCenter: parent.verticalCenter

                                    Text {
                                        text: "/" + modelData.name
                                        color: Kirigami.Theme.textColor
                                        font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.95
                                        font.bold: true
                                    }
                                    Text {
                                        text: modelData.desc
                                        color: root.colorWithAlpha(Kirigami.Theme.textColor, 0.6)
                                        font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.82
                                    }
                                }
                            }

                            MouseArea {
                                id: cmdItemHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    executable.exec(modelData.cmd);
                                    root.toggle();
                                }
                            }
                        }
                    }
                }

                // ── Results grid ──
                ItemMultiGridView {
                    id: runnerGrid
                    anchors.top: filterPillsWrapper.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    visible: !(root.searching && searchField.text.startsWith('/'))
                    itemColumns: 3
                    cellWidth: rootItem.widthComputed - Kirigami.Units.gridUnit * 2
                    cellHeight: root.iconSize + Kirigami.Units.gridUnit + Kirigami.Units.largeSpacing
                    model: runnerModel
                    grabFocus: true
                    focus: view.currentIndex === 1
                    onKeyNavUp: {
                        runnerGrid.focus = false;
                        searchField.focus = true;
                    }
                }

                // ── Plugin search results ──
                Column {
                    id: pluginResultsColumn
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: Kirigami.Units.smallSpacing
                    spacing: 2
                    visible: root.searching
                             && !searchField.text.startsWith('/')
                             && !searchField.text.startsWith('>')
                             && rootItem.pluginResults.length > 0

                    Repeater {
                        model: rootItem.pluginResults

                        delegate: Item {
                            id: pluginResultItem
                            width: pluginResultsColumn.width
                            height: Kirigami.Units.gridUnit * 3

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 2
                                radius: Kirigami.Units.smallSpacing
                                color: pluginResultHover.containsMouse
                                       ? root.colorWithAlpha(Kirigami.Theme.highlightColor, 0.10)
                                       : "transparent"
                                border.width: 1
                                border.color: root.colorWithAlpha(Kirigami.Theme.textColor, 0.07)
                                Behavior on color { ColorAnimation { duration: 80 } }
                            }

                            Row {
                                anchors.left: parent.left
                                anchors.leftMargin: Kirigami.Units.smallSpacing * 2
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Kirigami.Units.smallSpacing

                                Kirigami.Icon {
                                    source: modelData.icon || "edit-find"
                                    width: Kirigami.Units.iconSizes.smallMedium
                                    height: width
                                    anchors.verticalCenter: parent.verticalCenter
                                    animated: false
                                }

                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 1

                                    Text {
                                        text: modelData.title || ""
                                        color: Kirigami.Theme.textColor
                                        font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.95
                                        elide: Text.ElideRight
                                        width: pluginResultsColumn.width
                                               - Kirigami.Units.iconSizes.smallMedium
                                               - Kirigami.Units.smallSpacing * 4
                                    }

                                    Text {
                                        visible: modelData.subtitle !== undefined && modelData.subtitle !== ""
                                        text: modelData.subtitle || ""
                                        color: root.colorWithAlpha(Kirigami.Theme.textColor, 0.55)
                                        font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.78
                                        elide: Text.ElideRight
                                        width: pluginResultsColumn.width
                                               - Kirigami.Units.iconSizes.smallMedium
                                               - Kirigami.Units.smallSpacing * 4
                                    }
                                }
                            }

                            MouseArea {
                                id: pluginResultHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    var act = modelData.action;
                                    if (typeof act === "function") act();
                                    else if (typeof act === "string") executable.exec(act);
                                    root.toggle();
                                }
                            }

                            Keys.onReturnPressed: {
                                var act = modelData.action;
                                if (typeof act === "function") act();
                                else if (typeof act === "string") executable.exec(act);
                                root.toggle();
                            }
                        }
                    }
                }

                // ── Empty state ──
                Column {
                    anchors.centerIn: parent
                    visible: root.searching && !searchField.text.startsWith('/') && runnerGrid.count === 0
                    spacing: Kirigami.Units.largeSpacing

                    Kirigami.Icon {
                        source: searchField.text.startsWith('>') && Plasmoid.configuration.enableShellRunner
                                ? "utilities-terminal" : "edit-find-none"
                        width: Kirigami.Units.iconSizes.huge
                        height: width
                        anchors.horizontalCenter: parent.horizontalCenter
                        opacity: 0.4
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: {
                            if (searchField.text.startsWith('>') && Plasmoid.configuration.enableShellRunner) {
                                var cmd = searchField.text.slice(1).trim();
                                return cmd.length > 0
                                    ? i18n("Press Enter to run: %1", cmd)
                                    : i18n("Type a shell command after '>'");
                            }
                            if (kicker.searchRunnerFilter !== "all") {
                                return i18n("No results for \"%1\" in %2",
                                            searchField.text,
                                            ({ apps: i18n("Apps"), files: i18n("Files"), settings: i18n("Settings"), actions: i18n("Actions") })[kicker.searchRunnerFilter] || kicker.searchRunnerFilter);
                            }
                            return i18n("No results for \"%1\"", searchField.text);
                        }
                        color: Kirigami.Theme.textColor
                        opacity: 0.55
                        font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.95
                    }
                }
            }

            // PAGE 4 (index 2) — Nos recommandations (page complète : les 7 derniers jours)
            Item {
                id: recentPage
                width: view.width
                height: view.height

                function tryActivate(row, col) {
                    recentAllGrid.tryActivate(row, col);
                }

                RowLayout {
                    id: recentPageHeader
                    x: rootItem.sectionInset
                    width: rootItem.width - rootItem.margeCote * 2 - rootItem.sectionInset * 2
                    height: butttonActionAllApps.implicitHeight

                    PlasmaExtras.Heading {
                        color: colorWithAlpha(Kirigami.Theme.textColor, 0.8)
                        level: 5
                        text: i18n("Recommended")
                        font.weight: Font.Bold
                        Layout.alignment: Qt.AlignVCenter
                    }

                    Item { Layout.fillWidth: true }

                    SectionButton {
                        iconName: "go-previous"
                        iconLeft: true
                        text: i18n("Back")
                        onClicked: {
                            recentAllGrid.currentIndex = -1;
                            view.currentIndex = 0;
                        }
                    }
                }

                ItemGridView {
                    id: recentAllGrid
                    whiteHighlight: true // surlignement blanc 50 %
                    // le surlignement s'arrête juste après l'heure (pas au bord du menu)
                    highlightRightPad: Math.max(0, timeRightPad - Kirigami.Units.smallSpacing * 2)
                    onContentYChanged: rootItem.noteScrolling()
                    x: Math.max(0, rootItem.sectionInset - rootItem.listIconPad)
                    y: recentPageHeader.height + Kirigami.Units.largeSpacing
                    width: recentPage.width - x
                    height: recentPage.height - y
                    // l'heure s'arrête au même bord droit que les boutons de section
                    property int timeRightPad: Math.max(0, x + width - (rootItem.width - rootItem.margeCote * 2 - rootItem.sectionInset))
                    model: docsWeekModel
                    recentDocsMode: true
                    recentDocsWide: true
                    itemColumns: 1
                    dragEnabled: true
                    dropEnabled: false
                    verticalScrollBarPolicy: PC3.ScrollBar.AsNeeded
                    cellWidth: width
                    cellHeight: docsIconSize + Kirigami.Units.largeSpacing * 2
                    iconSize: docsIconSize
                    clip: true
                    onKeyNavUp: {
                        recentAllGrid.focus = false;
                        searchField.focus = true;
                    }
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Tab) {
                            event.accepted = true;
                            searchField.focus = true;
                            recentAllGrid.focus = false;
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: recentAllGrid.count === 0
                    text: i18n("No recent documents this week")
                    color: colorWithAlpha(Kirigami.Theme.textColor, 0.55)
                }
            }
        }

        // ── Fenêtre « Affichage » de la rubrique Tout (même style que la fenêtre du bouton Alimentation) ──
        // fenêtre système séparée : le menu principal ne doit pas se refermer quand elle prend le focus
        PlasmaCore.Dialog {
            id: viewModePopup
            flags: Qt.WindowStaysOnTopHint
            location: PlasmaCore.Types.Floating
            hideOnWindowDeactivate: true

            property Item anchorItem: null
            property bool keepMenuOpen: false

            onVisibleChanged: {
                if (visible) {
                    Qt.callLater(viewModePopup.reposition);
                } else {
                    kdeConnectPanel.hold = false;
                    root.hideOnWindowDeactivate = !kdeConnectPanel.visible;
                    if (keepMenuOpen) {
                        // choix fait dans cette fenêtre : le menu principal reste ouvert
                        keepMenuOpen = false;
                        root.requestActivate();
                    } else if (!root.active && !kdeConnectPanel.active) {
                        root.visible = false;
                    }
                }
            }

            function openFor(button) {
                anchorItem = button;
                kdeConnectPanel.hold = true;
                root.hideOnWindowDeactivate = false;
                visible = true;
            }

            function choose(mode) {
                // Fenestra : affichage rapide : le petit menu se ferme d'abord, le changement suit
                keepMenuOpen = true;
                visible = false;
                Qt.callLater(function () {
                    if (mode !== 2) allAppsGrid.model = null;   // un seul recalcul de la grille
                    Plasmoid.configuration.allAppsViewMode = mode;
                    if (mode === 2) root.ensureCategoryModel();
                    else rootItem.buildAllAppsCombo();
                });
            }

            function reposition() {
                if (!anchorItem) return;
                // sous le bouton, alignée sur son bord droit ; au-dessus s'il n'y a pas la place dans la hauteur du menu
                var pos = anchorItem.mapToGlobal(anchorItem.width, anchorItem.height);
                x = Math.round(pos.x - width);
                var below = Math.round(pos.y + Kirigami.Units.smallSpacing);
                y = (below + height <= root.y + root.height)
                    ? below
                    : Math.round(anchorItem.mapToGlobal(0, 0).y - height - Kirigami.Units.smallSpacing);
            }

            mainItem: ColumnLayout {
                spacing: 0

                Repeater {
                    model: [
                        { mode: 2, label: i18n("Categories") },
                        { mode: 1, label: i18n("Grid") },
                        { mode: 0, label: i18n("List") }
                    ]

                    delegate: PC3.ItemDelegate {
                        id: modeItem
                        Layout.fillWidth: true
                        hoverEnabled: true
                        leftPadding: Kirigami.Units.smallSpacing + 6
                        rightPadding: Kirigami.Units.smallSpacing + 6
                        topPadding: Kirigami.Units.smallSpacing
                        bottomPadding: Kirigami.Units.smallSpacing
                        readonly property bool current: Plasmoid.configuration.allAppsViewMode === modelData.mode

                        contentItem: RowLayout {
                            spacing: Kirigami.Units.smallSpacing + 6

                            Text {
                                text: "\u2713"
                                color: Kirigami.Theme.textColor
                                opacity: modeItem.current ? 1.0 : 0.0
                                font.pointSize: Kirigami.Theme.defaultFont.pointSize
                                Layout.preferredWidth: Kirigami.Units.gridUnit
                            }

                            PC3.Label {
                                text: modelData.label
                                Layout.fillWidth: true
                            }
                        }

                        background: Rectangle {
                            anchors.fill: parent
                            anchors.margins: 2
                            radius: Kirigami.Units.smallSpacing
                            color: Kirigami.Theme.highlightColor
                            opacity: parent.hovered ? 0.18 : 0.0
                            Behavior on opacity { NumberAnimation { duration: 100 } }
                        }

                        onClicked: viewModePopup.choose(modelData.mode)
                    }
                }
            }
        }

        // ── Fenêtre d'une catégorie (clic sur le paquet de mini-icônes ou sur le fond d'une tuile) ──
        Item {
            id: categoryFlyout
            anchors.fill: parent
            visible: false
            z: 260

            property int row: -1
            property string title: ""

            property real progress: 0          // 0 = fermée, 1 = ouverte
            property bool closing: false
            readonly property int revision: rootItem.categoryRevision   // reprend les nouveaux sous-modèles après un rafraîchissement
            property real startScale: 0.7        // taille de départ (0.5 = petit, 0.9 = discret)
            property real originX: width / 2     // point d'où la fenêtre sort (la tuile cliquée)
            property real originY: height / 2

            // catégorie contenant une nouveauté : les cellules gagnent une ligne pour le tag
            property bool hasNew: false
            // Fenestra : cette fenêtre force « labels2lines: true ». Si la config générale
            // n'est PAS sur 2 lignes, cellSizeHeight n'en réserve qu'une : on ajoute donc la
            // ligne manquante pour que le nom ne déborde pas de la tuile non plus ici.
            readonly property real cellH: root.cellSizeHeight
                                          + (Plasmoid.configuration.labels2lines ? 0 : root.labelLineHeight)
                                          + (hasNew ? Kirigami.Units.gridUnit : 0)

            ListModel { id: categoryFlatModel } // liste aplatie (plus de sous-tuiles de groupe)

            function refreshHasNew() {
                var found = false;
                if (rootItem.newApps) {
                    for (var i = 0; i < categoryFlatModel.count; i++) {
                        var fid = categoryFlatModel.get(i).favoriteId;
                        if (fid && rootItem.newApps[fid]) { found = true; break; }
                    }
                }
                hasNew = found;
            }

            Connections {
                target: rootItem
                function onNewAppsChanged() { categoryFlyout.refreshHasNew(); }
            }

            function openFor(r, t, sx, sy) {
                row = r;
                title = t;
                categoryFlatModel.clear();
                if (r >= 0 && typeof categoryRootModel !== "undefined") {
                    var flat = [];
                    rootItem.collectCategoryApps(categoryRootModel.modelForRow(r), flat, {});
                    for (var k = 0; k < flat.length; k++) categoryFlatModel.append(flat[k]);
                }
                refreshHasNew();
                if (sx !== undefined && sy !== undefined) {
                    var p = mapFromItem(null, sx, sy);
                    originX = p.x;
                    originY = p.y;
                } else {
                    originX = width / 2;
                    originY = height / 2;
                }
                closeAnim.stop();
                closing = false;
                progress = 0;
                visible = true;
                openAnim.restart();
            }

            // fermeture animée (sens inverse de l'ouverture)
            function close() {
                if (!visible || closing) return;
                closing = true;
                openAnim.stop();
                closeAnim.restart();
            }

            onVisibleChanged: {
                if (!visible) {           // fermeture immédiate (ex. le menu se ferme)
                    openAnim.stop();
                    closeAnim.stop();
                    progress = 0;
                    closing = false;
                }
            }

            NumberAnimation {
                id: openAnim
                target: categoryFlyout
                property: "progress"
                to: 1
                duration: 180
                easing.type: Easing.OutCubic
            }

            NumberAnimation {
                id: closeAnim
                target: categoryFlyout
                property: "progress"
                to: 0
                duration: 140
                easing.type: Easing.InCubic
                onFinished: {
                    categoryFlyout.closing = false;
                    categoryFlyout.visible = false;
                }
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                onPressed: mouse => {
                    categoryFlyout.close();
                    mouse.accepted = true;
                }
                onWheel: wheel => { wheel.accepted = true; }
            }

            Rectangle {
                id: flyBox
                anchors.centerIn: parent
                opacity: categoryFlyout.progress
                transform: Scale {
                    origin.x: categoryFlyout.originX - flyBox.x
                    origin.y: categoryFlyout.originY - flyBox.y
                    xScale: categoryFlyout.startScale + (1 - categoryFlyout.startScale) * categoryFlyout.progress
                    yScale: xScale
                }
                width: flyGrid.width + Kirigami.Units.gridUnit * 2
                height: flyTitle.implicitHeight + flyGrid.height + Kirigami.Units.gridUnit * 3
                radius: Kirigami.Units.smallSpacing * 2 + 2
                color: Kirigami.Theme.backgroundColor
                border.width: 1
                border.color: root.colorWithAlpha(Kirigami.Theme.textColor, 0.15)

                // un clic dans la fenêtre ne la ferme pas
                MouseArea {
                    anchors.fill: parent
                    onPressed: mouse => { mouse.accepted = true; }
                }

                Text {
                    id: flyTitle
                    anchors.top: parent.top
                    anchors.topMargin: Kirigami.Units.gridUnit
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: categoryFlyout.title
                    color: Kirigami.Theme.textColor
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.3
                    font.weight: Font.DemiBold
                }

                ItemGridView {
                    id: flyGrid
                    whiteHighlight: true // surlignement blanc 50 %
                    onContentYChanged: rootItem.noteScrolling()
                    anchors.top: flyTitle.bottom
                    anchors.topMargin: Kirigami.Units.gridUnit
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: root.cellSizeWidth * 4 + Kirigami.Units.gridUnit
                    height: Math.max(1, Math.min(3, Math.ceil(count / 4))) * categoryFlyout.cellH
                    itemColumns: 1
                    labels2lines: true
                    showNewTag: true
                    favoritesModelOverride: globalFavorites
                    dragEnabled: false // liste fusionnée : la réorganisation n'a pas de sens ici
                    dropEnabled: false
                    verticalScrollBarPolicy: PC3.ScrollBar.AsNeeded
                    cellWidth: root.cellSizeWidth
                    cellHeight: categoryFlyout.cellH
                    iconSize: root.iconSize
                    clip: true
                    model: categoryFlatModel
                }
            }
        }

        PlasmaExtras.PlasmoidHeading {
            id: footer
            contentWidth: parent.width
            contentHeight: Kirigami.Units.gridUnit * 3 - 10   // pied réduit de 10 px (aligné sur le volet KDE Connect)
            anchors.bottom: parent.bottom
            position: PC3.ToolBar.Footer

            Footer {
                id: footerContent
                anchors.fill: parent
                // Fenestra : hôte de l'infobulle partagée (dessinée dans rootItem)
                tipHost: rootItem
                // Fenestra : écran utile transmis au pied (la fenêtre Compte s'y borne)
                ecranUtile: root.ecranUtile
                // le menu se ferme -> les fenêtres Compte / Alimentation aussi
                Connections {
                    target: root
                    function onVisibleChanged() { if (!root.visible) footerContent.closeMenus(); }
                }
                anchors.leftMargin: rootItem.margeCote
                anchors.rightMargin: rootItem.margeCote
                onTabOut: searchField.forceActiveFocus()
                onPowerMenuAboutToOpen: { kdeConnectPanel.hold = true; root.hideOnWindowDeactivate = false; }
                onPowerMenuClosed: {
                    kdeConnectPanel.hold = false;
                    root.hideOnWindowDeactivate = !kdeConnectPanel.visible;
                    // Si le clic qui a fermé la fenêtre Alimentation était à
                    // l'intérieur du menu principal, root redevient actif -
                    // on le laisse ouvert. S'il était complètement en dehors
                    // (le bureau), on ferme tout, comme sur Windows 11.
                    if (!root.active && !kdeConnectPanel.active)
                        root.visible = false;
                }
                onAccountMenuAboutToOpen: { kdeConnectPanel.hold = true; root.hideOnWindowDeactivate = false; }
                onAccountMenuClosed: {
                    kdeConnectPanel.hold = false;
                    root.hideOnWindowDeactivate = !kdeConnectPanel.visible;
                    if (!root.active && !kdeConnectPanel.active)
                        root.visible = false;
                }
            }
        }

        // Fenestra : retour visuel « façon KDE » de la navigation alphabétique — la lettre
        // cliquée s'affiche en grand au centre de la page, puis s'efface (cf. jumpToLetter).
        Text {
            id: letterOverlay
            property string currentLetter: ""
            text: currentLetter
            enabled: false               // purement décoratif : ne capte aucun clic
            z: 50
            opacity: 0
            anchors.centerIn: view
            color: colorWithAlpha(Kirigami.Theme.textColor, 0.85)
            font.family: Kirigami.Theme.defaultFont.family
            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 6
            font.weight: Font.DemiBold
            Behavior on opacity { NumberAnimation { duration: 120 } }
        }

        Timer {
            id: overlayTimer
            interval: 700
            repeat: false
            onTriggered: letterOverlay.opacity = 0
        }

        // Fenestra : sélecteur de lettres (façon KDE Kickoff). Cliquer sur un en-tête
        // de lettre de la page « Tout » ouvre une page PLEINE ÉCRAN qui remplace la
        // liste des applis : on n'y voit que la grille des lettres + un bouton
        // « Retour ». Toutes les lettres A-Z ainsi que « & » (symboles) et « # »
        // (chiffres) sont affichées ; celles qui n'ont aucune application sont
        // grisées et non cliquables. Un clic sur une lettre disponible saute à
        // sa section.
        // Fenestra : la liste des lettres n'est PLUS codée en dur (A-Z/#/&). Elle est
        // construite dynamiquement à partir des en-têtes de section du modèle
        // (itemType === "letterHeader"), qui portent déjà la lettre « langue du système »
        // fournie par le rôle « group » de Kicker. Sous une locale japonaise on obtient
        // donc les colonnes de kana (あ/か/さ/…), en chinois les initiales pinyin, etc.
        property var availableLetters: ({})   // dictionnaire lettre -> true pour la recherche O(1)
        property var fullAlphabet: []          // liste ordonnée des lettres de la langue courante

        function refreshAvailableLetters() {
            var set = {};
            var ordered = [];
            for (var i = 0; i < allAppsComboModel.count; i++) {
                var e = allAppsComboModel.get(i);
                if (e.itemType === "letterHeader") {
                    var l = e.group || e.display;
                    if (l && !set[l]) {
                        set[l] = true;
                        ordered.push(l);
                    }
                }
            }
            rootItem.availableLetters = set;
            rootItem.fullAlphabet = ordered;
        }

        function openLetterPicker() {
            rootItem.refreshAvailableLetters();
            letterPicker.open();
        }

        Item {
            id: letterPicker
            visible: false
            z: 60
            anchors.fill: view

            // Fenestra : animation d'ouverture/fermeture calquée sur le volet de catégorie
            // (categoryFlyout). `progress` va de 0 (fermé) à 1 (ouvert). L'opacité et
            // l'échelle du contenu suivent `progress`. À l'ouverture : visible=true puis
            // openAnim ; à la fermeture : closeAnim puis visible=false dans onFinished.
            property real progress: 0
            property bool closing: false

            function open() {
                letterPicker.visible = true;
                letterPicker.closing = false;
                letterPickerOpenAnim.start();
            }
            function close() {
                if (letterPicker.closing) return;
                letterPicker.closing = true;
                letterPickerCloseAnim.start();
            }

            NumberAnimation {
                id: letterPickerOpenAnim
                target: letterPicker
                property: "progress"
                to: 1
                duration: 180
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                id: letterPickerCloseAnim
                target: letterPicker
                property: "progress"
                to: 0
                duration: 140
                easing.type: Easing.InCubic
                onFinished: {
                    letterPicker.closing = false;
                    letterPicker.visible = false;
                }
            }

            // Pas de fond propre : le sélecteur est transparent et laisse apparaître le
            // fond du dialogue Plasma lui-même (le FrameSvg « dialogs/background » dessiné
            // par PlasmaCore.Dialog derrière le mainItem). Comme c'est le dialogue qui peint
            // son propre fond, la couleur, le dégradé et la texture correspondent EXACTEMENT
            // à l'apparence Plasma 6 du thème, sans risque de décalage (fond blanc solide vs
            // fond du thème). La liste des applications est masquée en mettant l'opacité de
            // la vue à 0 quand le sélecteur est ouvert (cf. SwipeView « view »).

            // en-tête : bouton « Retour » en haut à droite, même style que les autres
            // boutons du menu (SectionButton) pour une apparence Plasma 6 cohérente.
            Item {
                id: pickerHeader
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: backBtn.implicitHeight + Kirigami.Units.gridUnit
                opacity: letterPicker.progress
                Behavior on opacity { NumberAnimation { duration: 80 } }

                SectionButton {
                    id: backBtn
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.rightMargin: rootItem.margeCote
                    iconName: "go-previous"
                    iconLeft: true
                    text: i18n("Back")
                    buttonHeight: 28
                    onClicked: letterPicker.close()
                }
            }

            Grid {
                id: letterGrid
                anchors.centerIn: parent
                opacity: letterPicker.progress
                transform: Scale {
                    origin.x: letterGrid.width / 2
                    origin.y: letterGrid.height / 2
                    xScale: 0.7 + 0.3 * letterPicker.progress
                    yScale: xScale
                }
                columns: {
                    var cell = Kirigami.Units.gridUnit * 2.8;
                    var spacing = Kirigami.Units.gridUnit;
                    // largeur utile = largeur du sélecteur - marges latérales
                    var usable = letterPicker.width - Kirigami.Units.gridUnit * 2;
                    // N colonnes de largeur « cell » séparées par « spacing » :
                    //   total = N * cell + (N - 1) * spacing = N * (cell + spacing) - spacing
                    // On cherche le plus grand N tel que total <= usable :
                    //   N <= (usable + spacing) / (cell + spacing)
                    // (Sans tenir compte du spacing, la grille débordait et la dernière
                    // colonne était tronquée — cf. lettre « L » coupée à droite.)
                    return Math.max(1, Math.min(8, Math.floor((usable + spacing) / (cell + spacing))));
                }
                spacing: Kirigami.Units.gridUnit

                Repeater {
                    model: rootItem.fullAlphabet
                    delegate: Item {
                        readonly property string letter: modelData
                        readonly property bool letterAvailable: rootItem.availableLetters[letter] === true

                        width: Kirigami.Units.gridUnit * 2.8
                        height: width

                        Rectangle {
                            anchors.fill: parent
                            radius: 6
                            color: {
                                if (!letterAvailable) return "transparent";
                                if (letterCellMouse.pressed) return colorWithAlpha(Kirigami.Theme.highlightColor, 0.35);
                                if (letterCellMouse.containsMouse) return colorWithAlpha(Kirigami.Theme.highlightColor, 0.22);
                                return "transparent";
                            }
                            // contour visible au survol (lettres disponibles uniquement)
                            border.width: (letterAvailable && letterCellMouse.containsMouse) ? 1 : 0
                            border.color: colorWithAlpha(Kirigami.Theme.highlightColor, 0.7)
                            Behavior on color { ColorAnimation { duration: 80 } }

                            Text {
                                anchors.centerIn: parent
                                text: letter
                                color: letterAvailable
                                    ? Kirigami.Theme.textColor
                                    : Kirigami.Theme.disabledTextColor
                                font.family: Kirigami.Theme.defaultFont.family
                                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.8
                                font.weight: Font.DemiBold
                            }

                            MouseArea {
                                id: letterCellMouse
                                anchors.fill: parent
                                enabled: letterAvailable
                                hoverEnabled: true
                                cursorShape: Qt.ArrowCursor
                                onClicked: {
                                    root.jumpToLetter(letter);
                                    letterPicker.close();
                                }
                            }
                        }
                    }
                }
            }
        }

        Timer {
            id: searchDebounce
            interval: 120
            repeat: false
            onTriggered: {
                runnerModel.query = searchField.text;
                rootItem.refreshPluginResults(searchField.text);
            }
        }

        // ── Fenêtre de catégorie — activation dispatch (liste aplatie) ───────
        Connections {
            target: flyGrid
            function onItemActivated(index, actionId, argument) {
                if (index < 0 || index >= categoryFlatModel.count) return;
                var entry = categoryFlatModel.get(index);
                if (entry.srcModel) {
                    entry.srcModel.trigger(entry.srcRow, actionId, argument);
                    root.toggle();
                }
            }
        }

        // ── All Apps grid — activation dispatch ──────────────────────────────
        Connections {
            target: allAppsGrid
            function onItemActivated(index, actionId, argument) {
                if (index < 0 || index >= allAppsComboModel.count) return;
                var entry = allAppsComboModel.get(index);
                if (entry.itemType === "letterHeader") return;
                if (entry.itemType === "folder") {
                    rootItem.toggleFolderExpand(index);
                } else {
                    // App item (regular or indented folder child)
                    if (entry.sourceRow >= 0) {
                        sortedAppsModel.trigger(entry.sourceRow, "", null);
                        root.toggle();
                    } else {
                        // Indented child — look up row in sortedAppsModel by favoriteId
                        for (var i = 0; i < sortedAppsModel.rowCount(); i++) {
                            var midx = sortedAppsModel.index(i, 0);
                            if (sortedAppsModel.data(midx, rootItem.kickerFavoriteIdRole) === entry.favoriteId) {
                                sortedAppsModel.trigger(i, "", null);
                                root.toggle();
                                return;
                            }
                        }
                    }
                }
            }
            // Fenestra : clic sur un en-tête de lettre -> ouvre le sélecteur de lettres
            // (grille de toutes les lettres disponibles) ; le choix d'une lettre s'y
            // fait, puis saute à la section (cf. letterPicker / jumpToLetter).
            function onLetterActivated(letter) { rootItem.openLetterPicker(); }
        }

        // ── All Apps grid: folder edit button dispatch ───────────────────────
        Connections {
            target: allAppsGrid
            function onFolderEditRequested(index) {
                if (index < 0 || index >= allAppsComboModel.count) return
                var entry = allAppsComboModel.get(index)
                if (!entry || entry.itemType !== "folder") return
                var cols = Math.max(1, Math.floor(allAppsGrid.width / allAppsGrid.cellWidth))
                var row = Math.floor(index / cols)
                var itemY = row * allAppsGrid.cellHeight - allAppsGrid.contentY
                var p = allAppsGrid.mapToItem(rootItem, allAppsGrid.width * 0.55,
                                              itemY + allAppsGrid.cellHeight)
                rootItem.openFolderAppPicker(entry.folderIdx, p.x, p.y)
            }
        }

        // ── Folder content popup (Windows 11 style: centered modal + icon grid) ──
        // Dismiss layer — covers the ENTIRE dialog (including frame margins).
        // No dim background; clicking outside closes the popup.
        MouseArea {
            id: folderPopupDismiss
            x: -(root.margins.left || 0)
            y: -(root.margins.top || 0)
            width: root.width
            height: root.height
            z: 198
            visible: folderContentPopup.visible
            onClicked: folderContentPopup.visible = false
        }

        Item {
            id: folderContentPopup
            visible: false
            z: 200
            scale: 0.85
            opacity: 0
            transformOrigin: Item.Center
            // Center within the full dialog (matches the overlay coverage)
            x: (root.width - width) / 2 - (root.margins.left || 0)
            y: (root.height - height) / 2 - (root.margins.top || 0)
            // 4 tiles per row: tile widths + 3 gaps + the inner Column's two margins.
            // The old formula under-counted the gaps (largeSpacing*3 < smallSpacing*3+2*largeSpacing),
            // which made the Flow wrap after only 3 tiles.
            width: Math.min(rootItem.width - Kirigami.Units.largeSpacing * 2,
                            root.cellSizeWidth * 4 + Kirigami.Units.smallSpacing * 3
                            + Kirigami.Units.largeSpacing * 2 + 1)
            height: popupBg.height

            Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }
            Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

            onVisibleChanged: {
                if (visible) {
                    scale = 1;
                    opacity = 1;
                } else {
                    scale = 0.85;
                    opacity = 0;
                }
            }

            function showAt(idx, tileX, tileY, tileW, tileH) {
                // Purge des lanceurs désépinglés avant l'affichage : si le
                // dossier est vide de tout favori il est dissous et on n'ouvre rien.
                if (!rootItem.purgerDossierEpingle(idx)) return;
                folderContentPopup.property_folderIndex = idx;
                visible = true;
            }

            property int property_folderIndex: -1

            Rectangle {
                id: popupBg
                width: parent.width
                height: popupColumn.implicitHeight + Kirigami.Units.largeSpacing * 2
                radius: Kirigami.Units.smallSpacing * 2
                color: Kirigami.Theme.backgroundColor
                border.width: 1
                border.color: root.colorWithAlpha(Kirigami.Theme.textColor, 0.15)

                Column {
                    id: popupColumn
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Kirigami.Units.largeSpacing
                    spacing: Kirigami.Units.largeSpacing

                    // Folder name — inline editable (click to rename directly)
                    PC3.TextField {
                        id: folderTitleField
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: Math.min(parent.width - Kirigami.Units.largeSpacing * 2,
                                        implicitWidth + Kirigami.Units.largeSpacing * 2)
                        text: folderContentPopup.property_folderIndex >= 0 && folderContentPopup.property_folderIndex < rootItem.pinnedFoldersData.length
                              ? rootItem.pinnedFoldersData[folderContentPopup.property_folderIndex].name
                              : ""
                        font.bold: true
                        color: Kirigami.Theme.textColor
                        font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.05
                        horizontalAlignment: Text.AlignHCenter
                        selectByMouse: true
                        cursorDelegate: Rectangle { color: Kirigami.Theme.textColor; width: 1 }
                        background: Rectangle {
                            color: "transparent"
                            border.width: 0
                        }

                        function commit() {
                            var fi = folderContentPopup.property_folderIndex;
                            if (fi < 0 || fi >= rootItem.pinnedFoldersData.length) return;
                            var newName = text.trim();
                            if (newName.length === 0) {
                                // Revert to current name if empty
                                text = rootItem.pinnedFoldersData[fi].name;
                                return;
                            }
                            var folders = rootItem.pinnedFoldersData.slice();
                            var old = folders[fi];
                            if (old.name !== newName) {
                                folders[fi] = { name: newName, items: old.items, createdAt: old.createdAt || 0 };
                                rootItem.pinnedFoldersData = folders;
                                rootItem.saveFolders();
                            }
                        }

                        Keys.onReturnPressed: commit()
                        Keys.onEnterPressed: commit()
                        Keys.onEscapePressed: {
                            text = folderContentPopup.property_folderIndex >= 0
                                   ? rootItem.pinnedFoldersData[folderContentPopup.property_folderIndex].name
                                   : "";
                            focus = false;
                        }
                        onEditingFinished: commit()
                    }

                    // App grid
                    Flow {
                        width: parent.width
                        spacing: Kirigami.Units.smallSpacing

                        Repeater {
                            model: rootItem.itemsDossierEpingles(folderContentPopup.property_folderIndex)

                            delegate: Item {
                                width: root.cellSizeWidth
                                height: root.cellSizeHeight

                                property string favId: modelData

                                // Hover background
                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: Kirigami.Units.smallSpacing / 2
                                    radius: Kirigami.Units.smallSpacing + 2
                                    color: tileHover.containsMouse
                                           ? root.colorWithAlpha(Kirigami.Theme.highlightColor, 0.12)
                                           : "transparent"
                                    Behavior on color { ColorAnimation { duration: 80 } }
                                }

                                Column {
                                    anchors.centerIn: parent
                                    spacing: Kirigami.Units.smallSpacing

                                    Kirigami.Icon {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        source: rootItem.iconSourceForId(favId)
                                        width: Kirigami.Units.iconSizes.huge
                                        height: width
                                        animated: false
                                    }

                                    Text {
                                        width: root.cellSizeWidth - Kirigami.Units.largeSpacing * 2
                                        text: rootItem.nameForId(favId)
                                        color: Kirigami.Theme.textColor
                                        font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.85
                                        horizontalAlignment: Text.AlignHCenter
                                        elide: Text.ElideRight
                                        maximumLineCount: 1
                                    }
                                }

                                MouseArea {
                                    id: tileHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor

                                    property real pressX: -1
                                    property real pressY: -1
                                    property bool dragStarted: false

                                    onPressed: {
                                        pressX = mouse.x;
                                        pressY = mouse.y;
                                        dragStarted = false;
                                    }

                                    onPositionChanged: {
                                        if (pressX !== -1 && !dragStarted
                                            && dragHelper.isDrag(pressX, pressY, mouse.x, mouse.y)) {
                                            var srcUrl = rootItem.urlForId(favId);
                                            if (!srcUrl) return;  // can't start a drag; keep pressX so a click still launches

                                            // Drag out of folder: remove from folder so it
                                            // reappears in the pinned grid, then start drag.
                                            var fi = folderContentPopup.property_folderIndex;
                                            if (fi >= 0 && fi < rootItem.pinnedFoldersData.length) {
                                                var folders = rootItem.pinnedFoldersData.slice();
                                                var folder = folders[fi];
                                                var idx = folder.items.indexOf(favId);
                                                if (idx >= 0) {
                                                    var newItems = folder.items.slice();
                                                    newItems.splice(idx, 1);
                                                    if (newItems.length === 0) {
                                                        // Folder became empty → dissolve it.
                                                        folders.splice(fi, 1);
                                                        folderContentPopup.visible = false;
                                                    } else {
                                                        folders[fi] = {
                                                            name: folder.name,
                                                            items: newItems,
                                                            createdAt: folder.createdAt || 0
                                                        };
                                                    }
                                                    rootItem.pinnedFoldersData = folders;
                                                    rootItem.saveFolders();
                                                }
                                            }
                                            dragHelper.startDrag(kicker, srcUrl);
                                            dragStarted = true;
                                            pressX = -1;
                                            pressY = -1;
                                        }
                                    }

                                    onReleased: {
                                        if (!dragStarted && !dragHelper.dragging) {
                                            folderContentPopup.visible = false;
                                            rootItem.launchFolderApp(favId);
                                        }
                                        pressX = -1;
                                        pressY = -1;
                                        dragStarted = false;
                                    }
                                }
                            }
                        }
                    }

                    // Empty state
                    Text {
                        visible: folderContentPopup.property_folderIndex >= 0
                                 && rootItem.itemsDossierEpingles(folderContentPopup.property_folderIndex).length === 0
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: i18n("Drag apps here to add them")
                        color: root.colorWithAlpha(Kirigami.Theme.textColor, 0.45)
                        font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.85
                        font.italic: true
                    }
                }
            }
        }

        // ── Create-folder overlay ────────────────────────────────────────────
        Item {
            id: createFolderOverlay
            anchors.fill: parent
            visible: false
            z: 202
            onVisibleChanged: {
                if (visible) {
                    newFolderNameField.text = "";
                    appPickerListView.checkedIds = [];
                }
            }

            // Dim background
            Rectangle {
                anchors.fill: parent
                color: "black"
                opacity: 0.45
                MouseArea { anchors.fill: parent; onClicked: createFolderOverlay.visible = false }
            }

            // Dialog card
            Rectangle {
                id: createDialog
                width: Math.min(340, rootItem.width - Kirigami.Units.largeSpacing * 4)
                height: dialogCol.implicitHeight + Kirigami.Units.largeSpacing * 2
                anchors.centerIn: parent
                radius: Kirigami.Units.smallSpacing * 2
                color: Kirigami.Theme.backgroundColor
                border.width: 1
                border.color: root.colorWithAlpha(Kirigami.Theme.textColor, 0.15)

                Column {
                    id: dialogCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Kirigami.Units.largeSpacing
                    spacing: Kirigami.Units.smallSpacing

                    Text {
                        text: i18n("New folder")
                        color: Kirigami.Theme.textColor
                        font.bold: true
                        font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.1
                    }

                    PC3.TextField {
                        id: newFolderNameField
                        width: parent.width
                        placeholderText: i18n("Folder name")
                    }

                    Text {
                        text: i18n("Choose from pinned apps:")
                        color: root.colorWithAlpha(Kirigami.Theme.textColor, 0.7)
                        font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.85
                        topPadding: Kirigami.Units.smallSpacing
                    }

                    // App picker list
                    Rectangle {
                        width: parent.width
                        height: 160
                        radius: Kirigami.Units.smallSpacing
                        color: root.colorWithAlpha(Kirigami.Theme.textColor, 0.05)
                        clip: true

                        ListView {
                            id: appPickerListView
                            anchors.fill: parent
                            anchors.margins: 4
                            model: globalFavorites
                            clip: true

                            property var checkedIds: []

                            delegate: Item {
                                width: appPickerListView.width
                                height: Kirigami.Units.gridUnit * 2.5

                                property string favId: model.favoriteId !== undefined ? model.favoriteId : ""
                                property bool isChecked: appPickerListView.checkedIds.indexOf(favId) >= 0

                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: 1
                                    radius: Kirigami.Units.smallSpacing
                                    color: pickHover.containsMouse
                                           ? root.colorWithAlpha(Kirigami.Theme.highlightColor, 0.08)
                                           : "transparent"
                                }

                                Row {
                                    anchors.fill: parent
                                    anchors.leftMargin: Kirigami.Units.smallSpacing
                                    anchors.rightMargin: Kirigami.Units.smallSpacing
                                    spacing: Kirigami.Units.smallSpacing

                                    CheckBox {
                                        anchors.verticalCenter: parent.verticalCenter
                                        checked: isChecked
                                        onToggled: {
                                            if (!favId) return;
                                            var arr = appPickerListView.checkedIds.slice();
                                            var idx = arr.indexOf(favId);
                                            if (checked && idx < 0) arr.push(favId);
                                            else if (!checked && idx >= 0) arr.splice(idx, 1);
                                            appPickerListView.checkedIds = arr;
                                        }
                                    }

                                    Kirigami.Icon {
                                        source: model.decoration !== undefined ? model.decoration : ""
                                        width: Kirigami.Units.iconSizes.small
                                        height: width
                                        animated: false
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Text {
                                        text: model.display !== undefined ? model.display : ""
                                        color: Kirigami.Theme.textColor
                                        font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.9
                                        elide: Text.ElideRight
                                        width: appPickerListView.width - Kirigami.Units.iconSizes.small
                                               - Kirigami.Units.gridUnit * 2 - Kirigami.Units.smallSpacing * 3
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                MouseArea {
                                    id: pickHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: {
                                        if (!favId) return;
                                        var arr = appPickerListView.checkedIds.slice();
                                        var idx = arr.indexOf(favId);
                                        if (idx >= 0) arr.splice(idx, 1);
                                        else arr.push(favId);
                                        appPickerListView.checkedIds = arr;
                                    }
                                }
                            }
                        }
                    }

                    // Action buttons
                    RowLayout {
                        width: parent.width

                        Item { Layout.fillWidth: true }

                        PC3.Button {
                            text: i18n("Cancel")
                            onClicked: createFolderOverlay.visible = false
                        }

                        PC3.Button {
                            text: i18n("Create")
                            highlighted: true
                            enabled: newFolderNameField.text.trim().length > 0
                                  && appPickerListView.checkedIds.length > 0
                            onClicked: {
                                var folders = rootItem.pinnedFoldersData.slice();
                                folders.push({
                                    name: newFolderNameField.text.trim(),
                                    items: appPickerListView.checkedIds.slice(),
                                    createdAt: Date.now()
                                });
                                rootItem.pinnedFoldersData = folders;
                                rootItem.saveFolders();
                                createFolderOverlay.visible = false;
                            }
                        }
                    }
                }
            }
        }

        // ── Folder context menu (right-click on tile) ───────────────────────
        Menu {
            id: folderContextMenu
            property int targetIndex: -1

            MenuItem {
                text: i18n("Delete folder")
                icon.name: "delete"
                onTriggered: {
                    var folders = rootItem.pinnedFoldersData.slice();
                    folders.splice(folderContextMenu.targetIndex, 1);
                    rootItem.pinnedFoldersData = folders;
                    rootItem.saveFolders();
                }
            }

            MenuItem {
                text: i18n("Unpin all apps in folder")
                icon.name: "bookmark-remove"
                onTriggered: {
                    if (folderContextMenu.targetIndex < 0) return;
                    var folder = rootItem.pinnedFoldersData[folderContextMenu.targetIndex];
                    if (!folder) return;
                    folder.items.forEach(function(id) {
                        if (globalFavorites.isFavorite(id))
                            globalFavorites.removeFavorite(id);
                    });
                    var folders = rootItem.pinnedFoldersData.slice();
                    folders.splice(folderContextMenu.targetIndex, 1);
                    rootItem.pinnedFoldersData = folders;
                    rootItem.saveFolders();
                }
            }
        }

        // ── All Apps folder popup ────────────────────────────────────────────
        MouseArea {
            anchors.fill: parent
            z: 199
            visible: allAppsFolderPopup.visible
            onClicked: allAppsFolderPopup.visible = false
        }

        Item {
            id: allAppsFolderPopup
            visible: false
            z: 200
            width: 240
            height: aafPopupBg.height

            property int folderIndex: -1

            function showAt(idx, tileX, tileY, tileW, tileH) {
                folderIndex = idx;
                var h = aafPopupBg.height;
                x = Math.max(0, Math.min(tileX, rootItem.width - width));
                y = tileY - h - Kirigami.Units.smallSpacing;
                if (y < 0) y = tileY + tileH + Kirigami.Units.smallSpacing;
                visible = true;
            }

            Rectangle {
                id: aafPopupBg
                width: parent.width
                height: aafPopupCol.implicitHeight + Kirigami.Units.largeSpacing * 2
                radius: Kirigami.Units.smallSpacing * 2
                color: Kirigami.Theme.backgroundColor
                border.width: 1
                border.color: root.colorWithAlpha(Kirigami.Theme.textColor, 0.15)

                Column {
                    id: aafPopupCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Kirigami.Units.smallSpacing
                    spacing: 2

                    Text {
                        leftPadding: Kirigami.Units.smallSpacing
                        text: allAppsFolderPopup.folderIndex >= 0
                              && allAppsFolderPopup.folderIndex < rootItem.allAppsFoldersData.length
                              ? rootItem.allAppsFoldersData[allAppsFolderPopup.folderIndex].name : ""
                        font.bold: true
                        color: Kirigami.Theme.textColor
                        font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.9
                    }

                    Repeater {
                        model: allAppsFolderPopup.folderIndex >= 0
                               && allAppsFolderPopup.folderIndex < rootItem.allAppsFoldersData.length
                               ? rootItem.allAppsFoldersData[allAppsFolderPopup.folderIndex].items : []

                        delegate: Item {
                            width: allAppsFolderPopup.width - Kirigami.Units.smallSpacing * 2
                            height: Kirigami.Units.gridUnit * 2.5

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 2
                                radius: Kirigami.Units.smallSpacing
                                color: aafAppHover.containsMouse
                                       ? root.colorWithAlpha(Kirigami.Theme.highlightColor, 0.12) : "transparent"
                                Behavior on color { ColorAnimation { duration: 80 } }
                            }

                            Row {
                                anchors.left: parent.left
                                anchors.leftMargin: Kirigami.Units.smallSpacing * 2
                                anchors.right: removeFromFolderBtn.left
                                anchors.rightMargin: Kirigami.Units.smallSpacing
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Kirigami.Units.smallSpacing

                                Kirigami.Icon {
                                    source: rootItem.iconSourceForId(modelData)
                                    width: Kirigami.Units.iconSizes.small; height: width
                                    animated: false
                                }
                                Text {
                                    text: rootItem.lookupAppInfo(modelData).name
                                    color: Kirigami.Theme.textColor
                                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.9
                                    elide: Text.ElideRight
                                    width: allAppsFolderPopup.width - Kirigami.Units.iconSizes.small
                                           - Kirigami.Units.gridUnit * 3.5
                                }
                            }

                            // Remove-from-folder × button
                            Text {
                                id: removeFromFolderBtn
                                anchors.right: parent.right
                                anchors.rightMargin: Kirigami.Units.smallSpacing * 2
                                anchors.verticalCenter: parent.verticalCenter
                                text: "×"
                                color: removeHover.containsMouse
                                       ? Kirigami.Theme.negativeTextColor
                                       : root.colorWithAlpha(Kirigami.Theme.textColor, 0.35)
                                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.1
                                visible: aafAppHover.containsMouse || removeHover.containsMouse

                                MouseArea {
                                    id: removeHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        var fi = allAppsFolderPopup.folderIndex;
                                        if (fi < 0 || fi >= rootItem.allAppsFoldersData.length) return;
                                        var folders = rootItem.allAppsFoldersData.slice();
                                        var folder = folders[fi];
                                        var idx = folder.items.indexOf(modelData);
                                        if (idx < 0) return;
                                        var newItems = folder.items.slice();
                                        newItems.splice(idx, 1);
                                        folders[fi] = { name: folder.name, items: newItems, createdAt: folder.createdAt || 0 };
                                        rootItem.allAppsFoldersData = folders;
                                        rootItem.saveAllAppsFolders();
                                    }
                                }
                            }

                            MouseArea {
                                id: aafAppHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    allAppsFolderPopup.visible = false;
                                    rootItem.launchFolderApp(modelData);
                                }
                            }
                        }
                    }

                    // Empty state
                    Text {
                        visible: allAppsFolderPopup.folderIndex >= 0
                                 && allAppsFolderPopup.folderIndex < rootItem.allAppsFoldersData.length
                                 && rootItem.allAppsFoldersData[allAppsFolderPopup.folderIndex].items.length === 0
                        leftPadding: Kirigami.Units.smallSpacing
                        topPadding: Kirigami.Units.smallSpacing
                        bottomPadding: Kirigami.Units.smallSpacing
                        text: i18n("Drag apps here to add them")
                        color: root.colorWithAlpha(Kirigami.Theme.textColor, 0.45)
                        font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.85
                        font.italic: true
                    }
                }
            }
        }

        // ── All Apps folder context menu ─────────────────────────────────────
        Menu {
            id: allAppsFolderContextMenu
            property int targetIndex: -1

            MenuItem {
                text: i18n("Rename folder")
                icon.name: "edit-rename"
                onTriggered: {
                    var idx = allAppsFolderContextMenu.targetIndex;
                    if (idx < 0 || idx >= rootItem.allAppsFoldersData.length) return;
                    aafRenameField.text = rootItem.allAppsFoldersData[idx].name;
                    aafRenameOverlay.targetIndex = idx;
                    aafRenameOverlay.visible = true;
                    aafRenameField.forceActiveFocus();
                    aafRenameField.selectAll();
                }
            }

            MenuItem {
                text: i18n("Delete folder")
                icon.name: "delete"
                onTriggered: {
                    var folders = rootItem.allAppsFoldersData.slice();
                    folders.splice(allAppsFolderContextMenu.targetIndex, 1);
                    rootItem.allAppsFoldersData = folders;
                    rootItem.saveAllAppsFolders();
                }
            }
        }

        // ── Create All Apps folder overlay ───────────────────────────────────
        Item {
            id: createAllAppsFolderOverlay
            anchors.fill: parent
            visible: false
            z: 202

            Rectangle {
                anchors.fill: parent
                color: "black"
                opacity: 0.45
                MouseArea { anchors.fill: parent; onClicked: createAllAppsFolderOverlay.visible = false }
            }

            Rectangle {
                width: Math.min(300, rootItem.width - Kirigami.Units.largeSpacing * 4)
                height: aafCreateCol.implicitHeight + Kirigami.Units.largeSpacing * 2
                anchors.centerIn: parent
                radius: Kirigami.Units.smallSpacing * 2
                color: Kirigami.Theme.backgroundColor
                border.width: 1
                border.color: root.colorWithAlpha(Kirigami.Theme.textColor, 0.15)

                Column {
                    id: aafCreateCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Kirigami.Units.largeSpacing
                    spacing: Kirigami.Units.smallSpacing

                    Text {
                        text: i18n("New folder")
                        color: Kirigami.Theme.textColor
                        font.bold: true
                        font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.1
                    }

                    PC3.TextField {
                        id: newAllAppsFolderNameField
                        width: parent.width
                        placeholderText: i18n("Folder name")
                        Keys.onReturnPressed: {
                            if (text.trim().length > 0) aafCreateBtn.clicked()
                        }
                        Keys.onEscapePressed: createAllAppsFolderOverlay.visible = false
                    }

                    Text {
                        text: i18n("Drag apps from the list into this folder to add them.")
                        color: root.colorWithAlpha(Kirigami.Theme.textColor, 0.6)
                        font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.82
                        wrapMode: Text.Wrap
                        width: parent.width
                    }

                    RowLayout {
                        width: parent.width
                        Item { Layout.fillWidth: true }
                        PC3.Button {
                            text: i18n("Cancel")
                            onClicked: createAllAppsFolderOverlay.visible = false
                        }
                        PC3.Button {
                            id: aafCreateBtn
                            text: i18n("Create")
                            highlighted: true
                            enabled: newAllAppsFolderNameField.text.trim().length > 0
                            onClicked: {
                                var folders = rootItem.allAppsFoldersData.slice();
                                folders.push({
                                    name: newAllAppsFolderNameField.text.trim(),
                                    items: [],
                                    createdAt: Date.now()
                                });
                                rootItem.allAppsFoldersData = folders;
                                rootItem.saveAllAppsFolders();
                                createAllAppsFolderOverlay.visible = false;
                            }
                        }
                    }
                }
            }
        }

        // ── All Apps folder rename overlay ───────────────────────────────────
        Item {
            id: aafRenameOverlay
            anchors.fill: parent
            visible: false
            z: 202
            property int targetIndex: -1

            Rectangle {
                anchors.fill: parent
                color: "black"
                opacity: 0.45
                MouseArea { anchors.fill: parent; onClicked: aafRenameOverlay.visible = false }
            }

            Rectangle {
                width: Math.min(300, rootItem.width - Kirigami.Units.largeSpacing * 4)
                height: aafRenameCol.implicitHeight + Kirigami.Units.largeSpacing * 2
                anchors.centerIn: parent
                radius: Kirigami.Units.smallSpacing * 2
                color: Kirigami.Theme.backgroundColor
                border.width: 1
                border.color: root.colorWithAlpha(Kirigami.Theme.textColor, 0.15)

                Column {
                    id: aafRenameCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Kirigami.Units.largeSpacing
                    spacing: Kirigami.Units.smallSpacing

                    Text {
                        text: i18n("Rename Folder")
                        color: Kirigami.Theme.textColor
                        font.bold: true
                        font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.1
                    }

                    PC3.TextField {
                        id: aafRenameField
                        width: parent.width
                        Keys.onReturnPressed: aafRenameConfirmBtn.clicked()
                        Keys.onEscapePressed: aafRenameOverlay.visible = false
                    }

                    RowLayout {
                        width: parent.width
                        Item { Layout.fillWidth: true }
                        PC3.Button {
                            text: i18n("Cancel")
                            onClicked: aafRenameOverlay.visible = false
                        }
                        PC3.Button {
                            id: aafRenameConfirmBtn
                            text: i18n("Rename")
                            highlighted: true
                            enabled: aafRenameField.text.trim().length > 0
                            onClicked: {
                                var idx = aafRenameOverlay.targetIndex;
                                var folders = rootItem.allAppsFoldersData.slice();
                                if (idx >= 0 && idx < folders.length) {
                                    folders[idx] = {
                                        name: aafRenameField.text.trim(),
                                        items: folders[idx].items,
                                        createdAt: folders[idx].createdAt || 0
                                    };
                                    rootItem.allAppsFoldersData = folders;
                                    rootItem.saveAllAppsFolders();
                                }
                                aafRenameOverlay.visible = false;
                            }
                        }
                    }
                }
            }
        }

        // ── All Apps folder app-picker popup ────────────────────────────────
        MouseArea {
            anchors.fill: parent
            z: 204
            visible: folderAppPickerPopup.visible
            onClicked: {
                folderAppPickerPopup.visible = false
                if (rootItem._needsComboRebuild) {
                    rootItem._needsComboRebuild = false
                    rootItem.buildAllAppsCombo()
                }
            }
        }

        Item {
            id: folderAppPickerPopup
            visible: false
            z: 205
            width: 300
            height: 400

            property int folderIndex: -1

            function openForFolder(idx, px, py) {
                folderIndex = idx
                pickerSearchField.text = ""
                rebuildPickerModel()
                var popW = width, popH = height
                x = Math.max(4, Math.min(px - popW / 2, rootItem.width - popW - 4))
                var yAbove = py - popH - 4
                y = yAbove >= 4 ? yAbove : Math.min(py + 4, rootItem.height - popH - 4)
                y = Math.max(4, y)
                visible = true
                pickerSearchField.forceActiveFocus()
            }

            function rebuildPickerModel() {
                pickerAppsModel.clear()
                if (folderIndex < 0 || folderIndex >= rootItem.allAppsFoldersData.length) return
                var folder = rootItem.allAppsFoldersData[folderIndex]
                var folderItems = folder.items || []
                var otherIds = {}
                for (var fi = 0; fi < rootItem.allAppsFoldersData.length; fi++) {
                    if (fi === folderIndex) continue
                    var f = rootItem.allAppsFoldersData[fi]
                    if (f.items) for (var j = 0; j < f.items.length; j++) otherIds[f.items[j]] = true
                }
                for (var i = 0; i < sortedAppsModel.rowCount(); i++) {
                    var midx = sortedAppsModel.index(i, 0)
                    var fid = sortedAppsModel.data(midx, rootItem.kickerFavoriteIdRole) || ""
                    if (!fid || otherIds[fid]) continue
                    pickerAppsModel.append({
                        appName: sortedAppsModel.data(midx, rootItem.kickerDisplayRole) || rootItem.displayNameForId(fid),
                        appIcon: sortedAppsModel.data(midx, rootItem.kickerDecorationRole) || rootItem.iconForId(fid),
                        appId: fid,
                        inFolder: folderItems.indexOf(fid) >= 0
                    })
                }
            }

            function toggleApp(appId) {
                if (folderIndex < 0 || folderIndex >= rootItem.allAppsFoldersData.length) return
                var folders = rootItem.allAppsFoldersData.slice()
                var folder = folders[folderIndex]
                var items = (folder.items || []).slice()
                var pos = items.indexOf(appId)
                var nowIn = pos < 0
                if (pos >= 0) items.splice(pos, 1)
                else items.push(appId)
                folders[folderIndex] = { name: folder.name, items: items, createdAt: folder.createdAt || 0 }
                rootItem.allAppsFoldersData = folders
                rootItem.saveAllAppsFolders()
                for (var i = 0; i < pickerAppsModel.count; i++) {
                    var e = pickerAppsModel.get(i)
                    if (e.appId === appId) {
                        pickerAppsModel.set(i, { appName: e.appName, appIcon: e.appIcon, appId: appId, inFolder: nowIn })
                        break
                    }
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: Kirigami.Units.smallSpacing * 2
                color: Kirigami.Theme.backgroundColor
                border.width: 1
                border.color: root.colorWithAlpha(Kirigami.Theme.textColor, 0.18)

                Column {
                    id: pickerFrameCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Kirigami.Units.largeSpacing
                    spacing: Kirigami.Units.smallSpacing

                    Text {
                        width: parent.width
                        text: folderAppPickerPopup.folderIndex >= 0
                              && folderAppPickerPopup.folderIndex < rootItem.allAppsFoldersData.length
                              ? i18n("Add apps — %1", rootItem.allAppsFoldersData[folderAppPickerPopup.folderIndex].name)
                              : i18n("Add apps to folder")
                        color: Kirigami.Theme.textColor
                        font.bold: true
                        font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.9
                        elide: Text.ElideRight
                    }

                    PC3.TextField {
                        id: pickerSearchField
                        width: parent.width
                        placeholderText: i18n("Filter…")
                        Keys.onEscapePressed: {
                            folderAppPickerPopup.visible = false
                            if (rootItem._needsComboRebuild) {
                                rootItem._needsComboRebuild = false
                                rootItem.buildAllAppsCombo()
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 310
                        color: root.colorWithAlpha(Kirigami.Theme.textColor, 0.04)
                        radius: Kirigami.Units.smallSpacing
                        clip: true

                        ListView {
                            id: pickerListView
                            anchors.fill: parent
                            anchors.margins: 2
                            model: pickerAppsModel
                            clip: true

                            PC3.ScrollBar.vertical: PC3.ScrollBar {
                                policy: pickerListView.contentHeight > pickerListView.height
                                        ? PC3.ScrollBar.AlwaysOn : PC3.ScrollBar.AlwaysOff
                                width: 6
                            }

                            delegate: Item {
                                readonly property bool matchesSearch: {
                                    var q = pickerSearchField.text.toLowerCase()
                                    return q === "" || model.appName.toLowerCase().indexOf(q) >= 0
                                }
                                width: pickerListView.width
                                height: matchesSearch ? Math.round(Kirigami.Units.gridUnit * 2.2) : 0
                                clip: true
                                visible: matchesSearch

                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: 1
                                    radius: Kirigami.Units.smallSpacing
                                    color: pickerRowHover.containsMouse
                                           ? root.colorWithAlpha(Kirigami.Theme.highlightColor, 0.12)
                                           : "transparent"
                                    Behavior on color { ColorAnimation { duration: 80 } }
                                }

                                Kirigami.Icon {
                                    id: pickerAppIcon
                                    anchors.left: parent.left
                                    anchors.leftMargin: Kirigami.Units.smallSpacing * 2
                                    anchors.verticalCenter: parent.verticalCenter
                                    source: model.appIcon
                                    width: Kirigami.Units.iconSizes.small
                                    height: width
                                    animated: false
                                }

                                Text {
                                    anchors.left: pickerAppIcon.right
                                    anchors.leftMargin: Kirigami.Units.smallSpacing
                                    anchors.right: pickerCheckRect.left
                                    anchors.rightMargin: Kirigami.Units.smallSpacing
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: model.appName
                                    color: Kirigami.Theme.textColor
                                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.9
                                    elide: Text.ElideRight
                                }

                                Rectangle {
                                    id: pickerCheckRect
                                    anchors.right: parent.right
                                    anchors.rightMargin: Kirigami.Units.smallSpacing * 2
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: Kirigami.Units.gridUnit
                                    height: width
                                    radius: 3
                                    border.width: 1.5
                                    border.color: model.inFolder
                                                  ? Kirigami.Theme.highlightColor
                                                  : root.colorWithAlpha(Kirigami.Theme.textColor, 0.35)
                                    color: model.inFolder ? Kirigami.Theme.highlightColor : "transparent"
                                    Behavior on color { ColorAnimation { duration: 80 } }
                                    Behavior on border.color { ColorAnimation { duration: 80 } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "✓"
                                        color: "white"
                                        font.pixelSize: parent.width * 0.62
                                        visible: model.inFolder
                                    }
                                }

                                MouseArea {
                                    id: pickerRowHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: folderAppPickerPopup.toggleApp(model.appId)
                                }
                            }
                        }
                    }
                }
            }

            ListModel { id: pickerAppsModel }
        }

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Control) {
                rootItem.ctrlHeld = true;
            }
            if (event.modifiers & Qt.ShiftModifier && event.text !== "") {
                searchField.focus = true;
                return;
            }
            // Ctrl+1..9 — quick-launch pinned apps on current page
            if (event.modifiers === Qt.ControlModifier) {
                var digit = event.key - Qt.Key_1;
                if (digit >= 0 && digit <= 8) {
                    var perPage = root.colonnesAuto * Plasmoid.configuration.numberRows;
                    var appIdx = rootItem.pinnedCurrentPage * perPage + digit;
                    if (appIdx < globalFavorites.count) {
                        event.accepted = true;
                        rootItem.recordLaunch(globalFavorites.favorites[appIdx]);
                        globalFavorites.trigger(appIdx, "", null);
                        root.toggle();
                    }
                    return;
                }
            }

            if (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_F) {
                event.accepted = true;
                searchField.focus = true;
                return;
            }
            if (event.key === Qt.Key_Escape) {
                event.accepted = true;
                if (categoryFlyout.visible) {
                        categoryFlyout.close();
                    } else if (viewModePopup.visible) {
                        viewModePopup.visible = false;
                    } else if (root.searching) {
                    reset();
                } else if (view.currentIndex === 2) {
                    view.currentIndex = 0;
                    searchField.focus = true;
                } else {
                    root.visible = false;
                }
                return;
            }

            if (searchField.focus) {
                return;
            }

            if (event.key === Qt.Key_Backspace) {
                event.accepted = true;
                searchField.backspace();
            } else if (event.text !== "") {
                event.accepted = true;
                searchField.appendText(event.text);
            }
        }

        Keys.onReleased: event => {
            if (event.key === Qt.Key_Control) {
                rootItem.ctrlHeld = false;
            }
        }
    }

    function setModels() {
        // Construire avant d'attacher : sinon la vue affiche le modèle vide
        // (clear) puis se remplit, ce qui produit un clignotement.
        rootItem.buildPinnedCombo();
        globalFavoritesGrid.model = pinnedComboModel;
        // Row order: [RecentApps(0), RecentDocs(1 if enabled), AllApps(1 or 2)]
        recentAppsListView.model = rootModel.modelForRow(0);
        var allAppsRow = Plasmoid.configuration.showRecentDocs ? 2 : 1;
        sortedAppsModel.sourceModel = rootModel.modelForRow(allAppsRow);
        // buildAllAppsCombo() réattache lui-même allAppsGrid.model à la fin
        rootItem.buildAllAppsCombo();
        if (Plasmoid.configuration.showRecentDocs) {
            docsLimitedModel.sourceModel = rootModel.modelForRow(1);
            documentsGrid.model = docsTopModel;
            rootItem.rebuildDocModels();
        }
    }

    property bool categoryModelLoaded: false

    function setCategoryModel() {
        allAppsCategoryGrid.model = categoryRootModel;
    }

    function ensureCategoryModel() {
        if (!categoryModelLoaded) {
            categoryModelLoaded = true;
            categoryRootModel.appletInterface = kicker;
            categoryRootModel.refreshed.connect(setCategoryModel);
            categoryRootModel.refresh();
        }
    }

    // Fenestra : navigation alphabétique (clic sur un en-tête de lettre de la page
    // « Tout »). Reproduit le comportement de KDE (plasma-desktop, section Applications :
    // « cliquez sur une lettre pour aller au premier élément de la section ») : la page
    // défile jusqu'à la section de la lettre, et la lettre choisie s'affiche en grand.
    // Important : dans ce fork c'est la PAGE (mainFlick) qui défile, pas la grille.
    function jumpToLetter(letter) {
        if (!letter || allAppsComboModel.count === 0) return;

        var targetIndex = -1;
        for (var i = 0; i < allAppsComboModel.count; i++) {
            var entry = allAppsComboModel.get(i);
            // Fenestra : la lettre provient du rôle « group » du modèle Kicker (langue
            // du système) ; l'en-tête porte la même lettre dans « group » et « display ».
            if (entry.itemType === "letterHeader"
                && (entry.group === letter || entry.display === letter)) {
                targetIndex = i;
                break;
            }
        }
        if (targetIndex < 0) return;

        var columns = Math.max(1, Math.floor(allAppsGrid.width / allAppsGrid.cellWidth));
        var targetY = allAppsGridContainer.y
                      + Math.floor(targetIndex / columns) * allAppsGrid.cellHeight
                      - Kirigami.Units.largeSpacing;
        mainFlick.scrollTo(targetY);

        letterOverlay.currentLetter = letter;
        letterOverlay.opacity = 1;
        overlayTimer.restart();
    }

    Component.onCompleted: {
        // Charger les dossiers AVANT la première construction des modèles :
        // sinon la première ouverture reconstruit la grille (tuiles-dossiers
        // ajoutées après coup), ce qui fait « sauter » la liste épinglée.
        rootItem.loadFolders();
        rootItem.loadAllAppsFolders();
        rootItem.loadPinnedOrder();
        rootModel.refreshed.connect(setModels);
        reset();
        rootModel.refresh();
        prechargement.start();
    }
}
