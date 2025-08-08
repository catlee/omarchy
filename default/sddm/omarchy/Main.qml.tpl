import QtQuick 2.0
import SddmComponents 2.0

Rectangle {
    id: root
    width: 640
    height: 480
    color: "{{ sddm_background }}"

    property string themeFont: "{{ sddm_font }}"

    property int userIndex: {
        for (var i = 0; i < userModel.rowCount(); i++) {
            var uname = (userModel.data(userModel.index(i, 0), Qt.DisplayRole) || "").toString()
            if (uname === userModel.lastUser)
                return i
        }
        return 0
    }
    property string currentUser: root.userName(root.userIndex)
    property int sessionIndex: {
        if (sessionModel.lastIndex >= 0 && sessionModel.lastIndex < sessionModel.rowCount())
            return sessionModel.lastIndex
        for (var i = 0; i < sessionModel.rowCount(); i++) {
            var name = (sessionModel.data(sessionModel.index(i, 0), Qt.DisplayRole) || "").toString()
            if (name.indexOf("uwsm") !== -1)
                return i
        }
        return 0
    }

    function sessionName(index) {
        if (index < 0 || index >= sessionModel.rowCount())
            return ""
        sessionLookup.currentIndex = index
        if (sessionLookup.currentItem && sessionLookup.currentItem.modelItem && sessionLookup.currentItem.modelItem.name)
            return sessionLookup.currentItem.modelItem.name.toString()
        return ""
    }

    function userName(index) {
        if (index < 0 || index >= userModel.rowCount())
            return userModel.lastUser || ""
        userLookup.currentIndex = index
        if (userLookup.currentItem && userLookup.currentItem.modelItem && userLookup.currentItem.modelItem.name)
            return userLookup.currentItem.modelItem.name.toString()
        return userModel.lastUser || ""
    }

    function cycleSession(step) {
        var count = sessionModel.rowCount()
        if (count <= 0)
            return
        var next = (sessionIndex + step + count) % count
        sessionIndex = next
    }

    function cycleUser(step) {
        var count = userModel.rowCount()
        if (count <= 0)
            return
        var next = (userIndex + step + count) % count
        userIndex = next
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            errorMessage.text = "Invalid password. Try again."
            password.text = ""
            password.focus = true
        }
        function onLoginSucceeded() {
            errorMessage.text = ""
        }
    }

    ListView {
        id: userLookup
        visible: false
        model: userModel
        delegate: Item { property var modelItem: model }
    }

    ListView {
        id: sessionLookup
        visible: false
        model: sessionModel
        delegate: Item { property var modelItem: model }
    }

    Image {
        source: config.background
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        smooth: true
        onStatusChanged: {
            if (status === Image.Error && source !== config.defaultBackground)
                source = config.defaultBackground
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "#88000000"
    }

    Rectangle {
        id: frame
        width: Math.min(root.width * 0.68, 520)
        height: Math.min(root.height * 0.58, 340)
        anchors.centerIn: parent
        color: "transparent"
        border.color: "{{ sddm_border_strong }}"
        border.width: 1

        Rectangle {
            anchors.fill: parent
            anchors.margins: 10
            color: "{{ sddm_panel_bg }}"
            border.color: "{{ sddm_border }}"
            border.width: 1

            Column {
                anchors.fill: parent
                anchors.margins: 26
                spacing: 18

                Image {
                    source: "logo.svg"
                    width: Math.min(frame.width * 0.46, 260)
                    height: Math.round(width * sourceSize.height / sourceSize.width)
                    fillMode: Image.PreserveAspectFit
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Row {
                    spacing: 10
                    anchors.horizontalCenter: parent.horizontalCenter

                    Text {
                        text: "user"
                        color: "{{ sddm_faint }}"
                        font.family: root.themeFont
                        font.pixelSize: 12
                    }
                    Text {
                        text: "‹"
                        color: "{{ sddm_muted }}"
                        font.family: root.themeFont
                        font.pixelSize: 15

                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.cycleUser(-1)
                            cursorShape: Qt.PointingHandCursor
                        }
                    }
                    Text {
                        text: root.currentUser.length > 0 ? root.currentUser : "user"
                        color: "{{ sddm_foreground }}"
                        font.family: root.themeFont
                        font.pixelSize: 15
                    }
                    Text {
                        text: "›"
                        color: "{{ sddm_muted }}"
                        font.family: root.themeFont
                        font.pixelSize: 15

                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.cycleUser(1)
                            cursorShape: Qt.PointingHandCursor
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 54
                    color: "{{ sddm_inner_panel_bg }}"
                    border.color: password.activeFocus ? "{{ sddm_accent }}" : "{{ sddm_border_strong }}"
                    border.width: 1
                    clip: true
                    anchors.horizontalCenter: parent.horizontalCenter

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        spacing: 10

                        Text {
                            text: "\uf023"
                            color: "{{ sddm_muted }}"
                            font.family: root.themeFont
                            font.pixelSize: 18
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        TextInput {
                            id: password
                            width: parent.width - 34
                            anchors.verticalCenter: parent.verticalCenter
                            verticalAlignment: TextInput.AlignVCenter
                            echoMode: TextInput.Password
                            font.family: root.themeFont
                            font.pixelSize: 17
                            font.letterSpacing: 0.8
                            passwordCharacter: "\u2022"
                            color: "{{ sddm_foreground }}"
                            selectionColor: "{{ sddm_selection_background }}"
                            selectedTextColor: "{{ sddm_selection_foreground }}"
                            focus: true

                            Keys.onPressed: {
                                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                    sddm.login(root.currentUser, password.text, root.sessionIndex)
                                    event.accepted = true
                                } else if (event.modifiers & Qt.ControlModifier && (event.key === Qt.Key_Up || event.key === Qt.Key_Left)) {
                                    root.cycleUser(-1)
                                    event.accepted = true
                                } else if (event.modifiers & Qt.ControlModifier && (event.key === Qt.Key_Down || event.key === Qt.Key_Right)) {
                                    root.cycleUser(1)
                                    event.accepted = true
                                } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Up) {
                                    root.cycleSession(-1)
                                    event.accepted = true
                                } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Down || event.key === Qt.Key_Tab) {
                                    root.cycleSession(1)
                                    event.accepted = true
                                }
                            }
                        }
                    }
                }

                Text {
                    id: errorMessage
                    text: ""
                    color: "{{ sddm_error }}"
                    font.family: root.themeFont
                    font.pixelSize: 14
                    wrapMode: Text.Wrap
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    text: "ENTER to login"
                    color: "{{ sddm_faint }}"
                    font.family: root.themeFont
                    font.pixelSize: 12
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
    }

    Row {
        spacing: 12
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 18
        anchors.horizontalCenter: parent.horizontalCenter

        Text {
            text: "session"
            color: "{{ sddm_faint }}"
            font.family: root.themeFont
            font.pixelSize: 11
        }
        Text {
            text: "‹"
            color: "{{ sddm_muted }}"
            font.family: root.themeFont
            font.pixelSize: 15

            MouseArea {
                anchors.fill: parent
                onClicked: root.cycleSession(-1)
                cursorShape: Qt.PointingHandCursor
            }
        }
        Text {
            text: root.sessionName(root.sessionIndex).length > 0 ? root.sessionName(root.sessionIndex) : "default"
            color: "{{ sddm_muted }}"
            font.family: root.themeFont
            font.pixelSize: 11
        }
        Text {
            text: "›"
            color: "{{ sddm_muted }}"
            font.family: root.themeFont
            font.pixelSize: 15

            MouseArea {
                anchors.fill: parent
                onClicked: root.cycleSession(1)
                cursorShape: Qt.PointingHandCursor
            }
        }
    }

    Rectangle {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 0
        anchors.horizontalCenter: parent.horizontalCenter
        width: frame.width
        height: 1
        color: "{{ sddm_border }}"
        opacity: 0.8
    }

    Component.onCompleted: {
        password.forceActiveFocus()
        errorMessage.text = ""
    }
}
