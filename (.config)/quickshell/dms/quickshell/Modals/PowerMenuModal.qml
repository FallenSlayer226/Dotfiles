import QtQuick
import Quickshell
import qs.Common
import qs.Modals.Common
import qs.Services
import qs.Widgets

DankModal {
    id: root

    layerNamespace: "dms:power-menu"

    property int selectedIndex: 0
    property rect parentBounds: Qt.rect(0, 0, 0, 0)
    property var parentScreen: null
    property var visibleActions: []

    signal powerActionRequested(string action, string title, string message)
    signal lockRequested

    function openCentered() {
        parentBounds = Qt.rect(0, 0, 0, 0)
        parentScreen = null
        backgroundOpacity = 0.5
        open()
    }

    function openFromControlCenter(bounds, targetScreen) {
        parentBounds = bounds
        parentScreen = targetScreen
        backgroundOpacity = 0
        open()
    }

    function updateVisibleActions() {
        const allActions = SettingsData.powerMenuActions || ["reboot", "logout", "poweroff", "lock", "suspend", "restart"]
        visibleActions = allActions.filter(action => {
                                               if (action === "hibernate" && !SessionService.hibernateSupported)
                                               return false
                                               return true
                                           })
    }

    function getDefaultActionIndex() {
        const defaultAction = SettingsData.powerMenuDefaultAction || "logout"
        const index = visibleActions.indexOf(defaultAction)
        return index >= 0 ? index : 0
    }

    function getActionAtIndex(index) {
        if (index < 0 || index >= visibleActions.length)
            return ""
        return visibleActions[index]
    }

    function getActionData(action) {
        switch (action) {
        case "reboot":
            return {
                "icon": "restart_alt",
                "label": I18n.tr("Reboot"),
                "key": "R"
            }
        case "logout":
            return {
                "icon": "logout",
                "label": I18n.tr("Log Out"),
                "key": "X"
            }
        case "poweroff":
            return {
                "icon": "power_settings_new",
                "label": I18n.tr("Power Off"),
                "key": "P"
            }
        case "lock":
            return {
                "icon": "lock",
                "label": I18n.tr("Lock"),
                "key": "L"
            }
        case "suspend":
            return {
                "icon": "bedtime",
                "label": I18n.tr("Suspend"),
                "key": "S"
            }
        case "hibernate":
            return {
                "icon": "ac_unit",
                "label": I18n.tr("Hibernate"),
                "key": "H"
            }
        case "restart":
            return {
                "icon": "refresh",
                "label": I18n.tr("Restart DMS"),
                "key": "D"
            }
        default:
            return {
                "icon": "help",
                "label": action,
                "key": "?"
            }
        }
    }

    function selectOption(action) {
        if (action === "lock") {
            close()
            lockRequested()
            return
        }
        if (action === "restart") {
            close()
            Quickshell.execDetached(["dms", "restart"])
            return
        }
        close()
        const actions = {
            "logout": {
                "title": I18n.tr("Log Out"),
                "message": I18n.tr("Are you sure you want to log out?")
            },
            "suspend": {
                "title": I18n.tr("Suspend"),
                "message": I18n.tr("Are you sure you want to suspend the system?")
            },
            "hibernate": {
                "title": I18n.tr("Hibernate"),
                "message": I18n.tr("Are you sure you want to hibernate the system?")
            },
            "reboot": {
                "title": I18n.tr("Reboot"),
                "message": I18n.tr("Are you sure you want to reboot the system?")
            },
            "poweroff": {
                "title": I18n.tr("Power Off"),
                "message": I18n.tr("Are you sure you want to power off the system?")
            }
        }
        const selected = actions[action]
        if (selected) {
            root.powerActionRequested(action, selected.title, selected.message)
        }
    }

    shouldBeVisible: false
    width: 400
    height: contentLoader.item ? contentLoader.item.implicitHeight : 300
    enableShadow: true
    screen: parentScreen
    positioning: parentBounds.width > 0 ? "custom" : "center"
    customPosition: {
        if (parentBounds.width > 0) {
            const centerX = parentBounds.x + (parentBounds.width - width) / 2
            const centerY = parentBounds.y + (parentBounds.height - height) / 2
            return Qt.point(centerX, centerY)
        }
        return Qt.point(0, 0)
    }
    onBackgroundClicked: () => close()
    onOpened: () => {
                  updateVisibleActions()
                  selectedIndex = getDefaultActionIndex()
                  Qt.callLater(() => modalFocusScope.forceActiveFocus())
              }
    Component.onCompleted: updateVisibleActions()
    modalFocusScope.Keys.onPressed: event => {
                                        switch (event.key) {
                                            case Qt.Key_Up:
                                            case Qt.Key_Backtab:
                                            selectedIndex = (selectedIndex - 1 + visibleActions.length) % visibleActions.length
                                            event.accepted = true
                                            break
                                            case Qt.Key_Down:
                                            case Qt.Key_Tab:
                                            selectedIndex = (selectedIndex + 1) % visibleActions.length
                                            event.accepted = true
                                            break
                                            case Qt.Key_Return:
                                            case Qt.Key_Enter:
                                            selectOption(getActionAtIndex(selectedIndex))
                                            event.accepted = true
                                            break
                                            case Qt.Key_N:
                                            if (event.modifiers & Qt.ControlModifier) {
                                                selectedIndex = (selectedIndex + 1) % visibleActions.length
                                                event.accepted = true
                                            }
                                            break
                                            case Qt.Key_P:
                                            if (!(event.modifiers & Qt.ControlModifier)) {
                                                selectOption("poweroff")
                                                event.accepted = true
                                            } else {
                                                selectedIndex = (selectedIndex - 1 + visibleActions.length) % visibleActions.length
                                                event.accepted = true
                                            }
                                            break
                                            case Qt.Key_J:
                                            if (event.modifiers & Qt.ControlModifier) {
                                                selectedIndex = (selectedIndex + 1) % visibleActions.length
                                                event.accepted = true
                                            }
                                            break
                                            case Qt.Key_K:
                                            if (event.modifiers & Qt.ControlModifier) {
                                                selectedIndex = (selectedIndex - 1 + visibleActions.length) % visibleActions.length
                                                event.accepted = true
                                            }
                                            break
                                            case Qt.Key_R:
                                            selectOption("reboot")
                                            event.accepted = true
                                            break
                                            case Qt.Key_X:
                                            selectOption("logout")
                                            event.accepted = true
                                            break
                                            case Qt.Key_L:
                                            selectOption("lock")
                                            event.accepted = true
                                            break
                                            case Qt.Key_S:
                                            selectOption("suspend")
                                            event.accepted = true
                                            break
                                            case Qt.Key_H:
                                            selectOption("hibernate")
                                            event.accepted = true
                                            break
                                            case Qt.Key_D:
                                            selectOption("restart")
                                            event.accepted = true
                                            break
                                        }
                                    }

    content: Component {
        Item {
            anchors.fill: parent
            implicitHeight: buttonColumn.implicitHeight + Theme.spacingL * 2

            Column {
                id: buttonColumn
                anchors {
                    left: parent.left
                    right: parent.right
                    leftMargin: Theme.spacingL
                    rightMargin: Theme.spacingL
                    verticalCenter: parent.verticalCenter
                }
                spacing: Theme.spacingS

                Repeater {
                    model: root.visibleActions

                    Rectangle {
                        required property int index
                        required property string modelData

                        readonly property var actionData: root.getActionData(modelData)
                        readonly property bool isSelected: root.selectedIndex === index
                        readonly property bool showWarning: modelData === "reboot" || modelData === "poweroff"

                        width: parent.width
                        height: 56
                        radius: Theme.cornerRadius
                        color: {
                            if (isSelected)
                                return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12)
                            if (mouseArea.containsMouse)
                                return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08)
                            return Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.08)
                        }
                        border.color: isSelected ? Theme.primary : "transparent"
                        border.width: isSelected ? 2 : 0

                        Row {
                            anchors {
                                left: parent.left
                                right: parent.right
                                leftMargin: Theme.spacingM
                                rightMargin: Theme.spacingM
                                verticalCenter: parent.verticalCenter
                            }
                            spacing: Theme.spacingM

                            DankIcon {
                                name: parent.parent.actionData.icon
                                size: Theme.iconSize + 4
                                color: {
                                    if (parent.parent.showWarning && mouseArea.containsMouse) {
                                        return parent.parent.modelData === "poweroff" ? Theme.error : Theme.warning
                                    }
                                    return Theme.surfaceText
                                }
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            StyledText {
                                text: parent.parent.actionData.label
                                font.pixelSize: Theme.fontSizeMedium
                                color: {
                                    if (parent.parent.showWarning && mouseArea.containsMouse) {
                                        return parent.parent.modelData === "poweroff" ? Theme.error : Theme.warning
                                    }
                                    return Theme.surfaceText
                                }
                                font.weight: Font.Medium
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        Rectangle {
                            width: 28
                            height: 20
                            radius: 4
                            color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.1)
                            anchors {
                                right: parent.right
                                rightMargin: Theme.spacingM
                                verticalCenter: parent.verticalCenter
                            }

                            StyledText {
                                text: parent.parent.actionData.key
                                font.pixelSize: Theme.fontSizeSmall
                                color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.6)
                                font.weight: Font.Medium
                                anchors.centerIn: parent
                            }
                        }

                        MouseArea {
                            id: mouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.selectedIndex = index
                                root.selectOption(modelData)
                            }
                        }
                    }
                }
            }
        }
    }
}
