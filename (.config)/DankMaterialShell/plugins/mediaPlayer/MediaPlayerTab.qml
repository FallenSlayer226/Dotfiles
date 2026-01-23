import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

DesktopPluginComponent {
    id: root

    // settings data here
    property real backgroundOpacity: (pluginData.backgroundOpacity ?? 80) / 100
    property real borderOpacity: (pluginData.borderOpacity ?? 100) / 100

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    opacity: showNoPlayerNow ? 0 : 1
    Behavior on opacity { NumberAnimation { duration: 300 } }

    property MprisPlayer activePlayer: MprisController.activePlayer
    property var allPlayers: MprisController.availablePlayers

    property bool isSwitching: false
    property string _lastArtUrl: ""
    property string _bgArtSource: ""

    property string activeTrackArtFile: ""

    function loadArtwork(url) {
        if (!url)
            return;
        if (url.startsWith("http://") || url.startsWith("https://")) {
            const filename = "/tmp/.dankshell/trackart_" + Date.now() + ".jpg";
            activeTrackArtFile = filename;

            cleanupProcess.command = ["sh", "-c", "mkdir -p /tmp/.dankshell && find /tmp/.dankshell -name 'trackart_*' ! -name '" + filename.split('/').pop() + "' -delete"];
            cleanupProcess.running = true;

            imageDownloader.command = ["curl", "-L", "-s", "--user-agent", "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36", "-o", filename, url];
            imageDownloader.targetFile = filename;
            imageDownloader.running = true;
            return;
        }
        _bgArtSource = url;
    }

    function maybeFinishSwitch() {
        if (activePlayer && activePlayer.trackTitle !== "") {
            isSwitching = false;
            _switchHold = false;
            _stalePositionDetected = false;
        }
    }
    
    function getDisplayPosition() {
        if (!activePlayer) return 0;
        
        const rawPos = Math.max(0, activePlayer.position || 0);
        const length = Math.max(1, activePlayer.length || 1);
        
        // If we detected stale position, show 0 until proper data arrives
        if (_stalePositionDetected) {
            return 0;
        }
        
        // Handle stale position data when switching videos
        if (isSwitching && rawPos >= length * 0.9) {
            return 0;
        }
        
        const pos = activePlayer.length ? rawPos % Math.max(1, activePlayer.length) : rawPos;
        return pos;
    }
    
    function formatTime(seconds) {
        const minutes = Math.floor(seconds / 60);
        const secs = Math.floor(seconds % 60);
        return minutes + ":" + (secs < 10 ? "0" : "") + secs;
    }
    
    Component.onCompleted: {
        // Initialize with current player state if available
        if (activePlayer) {
            // Get actual position after MPRIS fully loads
            Qt.callLater(() => {
                try {
                    const actualPos = activePlayer.position || 0;
                    const length = activePlayer.length || 1;
                    root._positionSnapshot = actualPos;
                    if (actualPos > 0) {
                        customSeekbar.seekbarValue = Math.min(1, actualPos / length);
                    }
                } catch (e) {
                    // Handle MPRIS errors
                }
            });
        }
    }

    // Derived "no players" state: always correct, no timers.
    readonly property int _playerCount: allPlayers ? allPlayers.length : 0
    readonly property bool _noneAvailable: _playerCount === 0
    readonly property bool _trulyIdle: activePlayer && activePlayer.playbackState === MprisPlaybackState.Stopped && !activePlayer.trackTitle && !activePlayer.trackArtist
    readonly property bool showNoPlayerNow: (!_switchHold) && (_noneAvailable || _trulyIdle)

    property bool _switchHold: false
    Timer {
        id: _switchHoldTimer
        interval: 650
        repeat: false
        onTriggered: {
            _switchHold = false;
            if (isSwitching) {
                isSwitching = false;
            }
        }
    }

    onActivePlayerChanged: {
        root._positionSnapshot = 0;
        root._forceUpdate = !root._forceUpdate;
        if (!activePlayer) {
            isSwitching = false;
            _switchHold = false;
            return;
        }
        isSwitching = true;
        _switchHold = true;
        _switchHoldTimer.restart();
        if (activePlayer.trackArtUrl)
            loadArtwork(activePlayer.trackArtUrl);
        
        // Get actual current position after a short delay to allow MPRIS to sync
        Qt.callLater(() => {
            try {
                const actualPos = activePlayer.position || 0;
                root._positionSnapshot = actualPos;
                if (actualPos > 0) {
                    customSeekbar.seekbarValue = Math.min(1, actualPos / Math.max(1, activePlayer.length || 1));
                    isSwitching = false;
                }
            } catch (e) {
                // Handle errors gracefully
            }
        });
    }



    // Responsive sizing with min/max constraints
    property real userScale: 1.0
    readonly property real minWidth: 320
    readonly property real maxWidth: 800
    readonly property real minHeight: 160
    readonly property real maxHeight: 400
    readonly property real baseWidth: 380
    readonly property real baseHeight: 200

    implicitWidth: Math.max(minWidth, Math.min(maxWidth, baseWidth * userScale))
    implicitHeight: Math.max(minHeight, Math.min(maxHeight, baseHeight * userScale))

    Connections {
        target: activePlayer
        function onTrackTitleChanged() {
            root._positionSnapshot = 0;
            root._forceUpdate = !root._forceUpdate;
            // Force immediate position reset for new track
            if (activePlayer.position > 0 && activePlayer.length > 0) {
                const progressRatio = activePlayer.position / activePlayer.length;
                if (progressRatio > 0.9) {
                    // Likely stale data - force reset
                    root._stalePositionDetected = true;
                }
            }
            _switchHoldTimer.restart();
            maybeFinishSwitch();
            // Reset progress bar immediately on track change
            customSeekbar.seekbarValue = 0;
        }
        function onTrackArtUrlChanged() {
            if (activePlayer?.trackArtUrl) {
                _lastArtUrl = activePlayer.trackArtUrl;
                loadArtwork(activePlayer.trackArtUrl);
            }
        }
        function onPositionChanged() {
            try {
                if (root._stalePositionDetected && activePlayer.position < activePlayer.length * 0.5) {
                    // Position updated properly now
                    root._stalePositionDetected = false;
                    root._forceUpdate = !root._forceUpdate;
                }
            } catch (e) {
                // MPRIS service disappeared - reset state
                root._stalePositionDetected = false;
            }
        }
    }

    Connections {
        target: MprisController
        function onAvailablePlayersChanged() {
            const count = (MprisController.availablePlayers?.length || 0);
            if (count === 0) {
                isSwitching = false;
                _switchHold = false;
            } else {
                _switchHold = true;
                _switchHoldTimer.restart();
            }
        }
    }

    Process {
        id: imageDownloader
        running: false
        property string targetFile: ""

        onExited: exitCode => {
            if (exitCode === 0 && targetFile)
                _bgArtSource = "file://" + targetFile;
        }
    }

    Process {
        id: cleanupProcess
        running: false
    }



    property bool isSeeking: false
    property real _positionSnapshot: 0
    property bool _forceUpdate: false
    property real _animationTick: 0
    property bool _stalePositionDetected: false

    Timer {
        id: positionUpdateTimer
        interval: 100
        running: true
        repeat: true
        onTriggered: {
            // Update snapshot to trigger binding re-evaluation
            if (activePlayer) {
                try {
                    const newPosition = activePlayer.position || 0;
                    root._positionSnapshot = newPosition;
                    // Force progress bar refresh when switching
                    if (isSwitching || _stalePositionDetected) {
                        customSeekbar.seekbarValue = customSeekbar.calculateProgress();
                    }
                } catch (e) {
                    // Handle MPRIS service errors gracefully
                    root._positionSnapshot = 0;
                }
            }
        }
    }

    // Use animation to drive constant updates for smooth progress bar
    NumberAnimation {
        id: progressUpdateAnimation
        target: root
        property: "_animationTick"
        from: 0
        to: 10000
        duration: 10000
        loops: Animation.Infinite
        running: activePlayer?.playbackState === MprisPlaybackState.Playing && !isSeeking
    }

    // Frosted glass background container
    Rectangle {
        id: bgContainer
        anchors.fill: parent
        radius: Theme.cornerRadius
        color: "transparent"
        border.color: Qt.rgba(1, 1, 1, 0.2)
        border.width: 1
        clip: true

        // Base frosted layer
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, root.backgroundOpacity * 0.6)
            
            // Glass gradient overlay
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.15) }
                GradientStop { position: 0.5; color: "transparent" }
                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.1) }
            }
        }

        // Top shine highlight
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: parent.height * 0.3
            radius: parent.radius
            color: "transparent"
            
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.25) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        // Subtle noise texture for glass realism (optional)
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            opacity: 0.03
            
            Canvas {
                anchors.fill: parent
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    
                    for (var i = 0; i < 500; i++) {
                        var x = Math.random() * width;
                        var y = Math.random() * height;
                        ctx.fillStyle = Math.random() > 0.5 ? "#ffffff" : "#000000";
                        ctx.fillRect(x, y, 1, 1);
                    }
                }
            }
        }

        // Inner border glow
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: parent.radius - 1
            color: "transparent"
            border.color: Qt.rgba(1, 1, 1, 0.15)
            border.width: 1
        }
    }
    
    // Main content container - Layout with thumbnail
    Item {
        anchors.fill: parent
        anchors.margins: Theme.spacingM * userScale
        visible: !_noneAvailable && (!showNoPlayerNow)

        Row {
            anchors.fill: parent
            spacing: Theme.spacingM * userScale

            // Album Thumbnail Section (Left)
            Rectangle {
                id: thumbnailContainer
                width: parent.height * 0.95
                height: parent.height * 0.95
                anchors.verticalCenter: parent.verticalCenter
                radius: 6 * userScale
                color: "transparent"
                clip: true

                property real albumRotation: 0

                NumberAnimation {
                    id: rotationAnimation
                    target: thumbnailContainer
                    property: "albumRotation"
                    from: 0
                    to: 360
                    duration: 20000
                    running: activePlayer?.playbackState === MprisPlaybackState.Playing
                    loops: Animation.Infinite
                }

                DankAlbumArt {
                    id: albumArt
                    width: parent.width * 0.95
                    height: parent.height * 0.95
                    anchors.centerIn: parent
                    activePlayer: root.activePlayer
                    rotation: thumbnailContainer.albumRotation
                }
            }

            // Content Section (Right)
            Column {
                width: parent.width - thumbnailContainer.width - parent.spacing
                height: parent.height
                spacing: Theme.spacingS * userScale

                // Song Info Section (Top)
                Column {
                    id: songInfo
                    width: parent.width
                    spacing: 2 * userScale

                    StyledText {
                        text: activePlayer?.trackTitle || "The (Overdue) Collapse of Wind..."
                        font.pixelSize: Theme.fontSizeMedium * 1.1 * userScale
                        font.weight: Font.Bold
                        color: Theme.surfaceText
                        width: parent.width
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }

                    StyledText {
                        text: activePlayer?.trackArtist || "Catalyst"
                        font.pixelSize: Theme.fontSizeSmall * userScale
                        color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.6)
                        width: parent.width
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }
                }

                // Spacer
                Item {
                    width: parent.width
                    height: Theme.spacingXS * userScale
                }

                // Controls Row (Middle)
                Row {
                    id: controlsRow
                    width: parent.width
                    spacing: Theme.spacingS * userScale

                    // Previous Button
                    Rectangle {
                        width: 32 * userScale
                        height: 32 * userScale
                        radius: 4 * userScale
                        color: "transparent"
                        anchors.verticalCenter: parent.verticalCenter

                        DankIcon {
                            anchors.centerIn: parent
                            name: "skip_previous"
                            size: 28 * userScale
                            color: Theme.primary
                        }

                        MouseArea {
                            id: prevBtnArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (!activePlayer)
                                    return;
                                if (activePlayer.position > 8 && activePlayer.canSeek) {
                                    activePlayer.position = 0;
                                } else {
                                    activePlayer.previous();
                                }
                            }
                        }
                    }

                    // Play/Pause Button
                    Rectangle {
                        width: 32 * userScale
                        height: 32 * userScale
                        radius: 4 * userScale
                        color: "transparent"
                        anchors.verticalCenter: parent.verticalCenter

                        DankIcon {
                            anchors.centerIn: parent
                            name: activePlayer && activePlayer.playbackState === MprisPlaybackState.Playing ? "pause" : "play_arrow"
                            size: 28 * userScale
                            color: Theme.primary
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: activePlayer && activePlayer.togglePlaying()
                        }
                    }

                    // Next Button
                    Rectangle {
                        width: 32 * userScale
                        height: 32 * userScale
                        radius: 4 * userScale
                        color: "transparent"
                        anchors.verticalCenter: parent.verticalCenter

                        DankIcon {
                            anchors.centerIn: parent
                            name: "skip_next"
                            size: 28 * userScale
                            color: Theme.primary
                        }

                        MouseArea {
                            id: nextBtnArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: activePlayer && activePlayer.next()
                        }
                    }

                    // Spacer to push buttons to right
                    Item {
                        width: parent.width - (32 * 3 * userScale) - (Theme.spacingS * 3 * userScale)
                        height: 1
                    }
                }

                // Seekbar Section (Bottom)
                Column {
                    id: seekbarSection
                    width: parent.width
                    spacing: 2 * userScale

                    // CUSTOM SEEKBAR - Edit this component to change appearance
                    Item {
                        id: customSeekbar
                        width: parent.width
                        height: 16 * userScale
                        
                        property real seekbarValue: 0
                        property bool isSeeking: false
                        
                        function calculateProgress() {
                            if (!root.activePlayer || root.activePlayer.length <= 0) return 0;
                            
                            const rawPos = Math.max(0, root.activePlayer.position || 0);
                            const length = Math.max(1, root.activePlayer.length || 1);
                            
                            if (root._stalePositionDetected) {
                                if (rawPos < length * 0.8) {
                                    root._stalePositionDetected = false;
                                    root.isSwitching = false;
                                } else {
                                    return 0;
                                }
                            }
                            
                            if (root.isSwitching && rawPos >= length * 0.9) {
                                root._stalePositionDetected = true;
                                return 0;
                            }
                            
                            if (root.isSwitching && rawPos > 0 && rawPos < length * 0.8) {
                                root.isSwitching = false;
                            }
                            
                            return Math.min(1, rawPos / length);
                        }
                        
                        // Background track - frosted glass style
                        Rectangle {
                            id: seekbarTrack
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            height: 6 * userScale
                            radius: 3 * userScale
                            color: Qt.rgba(1, 1, 1, 0.15)
                            border.color: Qt.rgba(1, 1, 1, 0.3)
                            border.width: 0.5
                            
                            // Inner shadow effect
                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 0.5
                                radius: parent.radius - 0.5
                                color: "transparent"
                                border.color: Qt.rgba(0, 0, 0, 0.1)
                                border.width: 0.5
                            }
                        }
                        
                        // Progress fill - frosted glass with blur
                        Item {
                            id: seekbarFillContainer
                            anchors.left: seekbarTrack.left
                            anchors.verticalCenter: seekbarTrack.verticalCenter
                            width: seekbarTrack.width * customSeekbar.seekbarValue
                            height: seekbarTrack.height
                            clip: true
                            
                            Behavior on width {
                                enabled: !customSeekbar.isSeeking
                                NumberAnimation { duration: 100 }
                            }
                            
                            Rectangle {
                                id: seekbarFill
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                width: seekbarTrack.width
                                height: seekbarTrack.height
                                radius: seekbarTrack.radius
                                
                                // Frosted glass gradient
                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.8) }
                                    GradientStop { position: 1.0; color: Qt.rgba(Theme.primary.r * 0.8, Theme.primary.g * 0.8, Theme.primary.b * 0.8, 0.9) }
                                }
                                
                                border.color: Qt.rgba(1, 1, 1, 0.4)
                                border.width: 0.5
                                
                                // Glass highlight
                                Rectangle {
                                    anchors.top: parent.top
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    height: parent.height * 0.4
                                    radius: parent.radius
                                    color: Qt.rgba(1, 1, 1, 0.3)
                                    
                                    gradient: Gradient {
                                        GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.3) }
                                        GradientStop { position: 1.0; color: "transparent" }
                                    }
                                }
                            }
                        }
                        
                        // Seek handle - frosted glass pill
                        Rectangle {
                            id: seekHandle
                            x: (customSeekbar.width * customSeekbar.seekbarValue) - (width / 2)
                            anchors.verticalCenter: parent.verticalCenter
                            width: 16 * userScale
                            height: 16 * userScale
                            radius: width / 2
                            visible: seekbarMouseArea.containsMouse || customSeekbar.isSeeking
                            
                            // Frosted glass effect
                            color: Qt.rgba(1, 1, 1, 0.9)
                            border.color: Qt.rgba(1, 1, 1, 0.6)
                            border.width: 1
                            
                            // Inner glow
                            Rectangle {
                                anchors.centerIn: parent
                                width: parent.width - 4
                                height: parent.height - 4
                                radius: width / 2
                                color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.3)
                            }
                            
                            // Shine effect
                            Rectangle {
                                anchors.top: parent.top
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.topMargin: 2
                                width: parent.width * 0.6
                                height: parent.height * 0.3
                                radius: width / 2
                                color: Qt.rgba(1, 1, 1, 0.5)
                            }
                            
                            // Drop shadow
                            layer.enabled: true
                            layer.effect: MultiEffect {
                                shadowEnabled: true
                                shadowColor: Qt.rgba(0, 0, 0, 0.3)
                                shadowBlur: 0.4
                                shadowVerticalOffset: 2
                                shadowHorizontalOffset: 0
                            }
                            
                            Behavior on x {
                                enabled: !customSeekbar.isSeeking
                                NumberAnimation { duration: 100 }
                            }
                            
                            Behavior on scale {
                                NumberAnimation { duration: 150 }
                            }
                            
                            scale: seekbarMouseArea.pressed ? 1.2 : 1.0
                        }
                        
                        // Mouse interaction
                        MouseArea {
                            id: seekbarMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            
                            onPressed: {
                                if (!root.activePlayer || !root.activePlayer.canSeek) return;
                                customSeekbar.isSeeking = true;
                                root.isSeeking = true;
                                const newValue = Math.max(0, Math.min(1, mouseX / width));
                                customSeekbar.seekbarValue = newValue;
                            }
                            
                            onPositionChanged: {
                                if (customSeekbar.isSeeking) {
                                    const newValue = Math.max(0, Math.min(1, mouseX / width));
                                    customSeekbar.seekbarValue = newValue;
                                }
                            }
                            
                            onReleased: {
                                if (customSeekbar.isSeeking && root.activePlayer && root.activePlayer.canSeek) {
                                    const seekPosition = customSeekbar.seekbarValue * root.activePlayer.length;
                                    root.activePlayer.position = seekPosition;
                                }
                                customSeekbar.isSeeking = false;
                                root.isSeeking = false;
                            }
                        }
                        
                        // Update timer
                        Timer {
                            interval: 50
                            running: true
                            repeat: true
                            onTriggered: {
                                if (!customSeekbar.isSeeking && root.activePlayer) {
                                    try {
                                        customSeekbar.seekbarValue = customSeekbar.calculateProgress();
                                    } catch (e) {
                                        // Handle MPRIS errors
                                    }
                                }
                            }
                        }
                    }

                    // Time labels
                    Item {
                        width: parent.width
                        height: 12 * userScale

                        StyledText {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: {
                                // Force dependency on position updates
                                root._positionSnapshot;
                                return formatTime(getDisplayPosition());
                            }
                            font.pixelSize: Theme.fontSizeSmall * 0.9 * userScale
                            color: Theme.surfaceVariantText
                        }

                        StyledText {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: {
                                if (!activePlayer || !activePlayer.length)
                                    return "0:00";
                                const dur = Math.max(0, activePlayer.length || 0);
                                const minutes = Math.floor(dur / 60);
                                const seconds = Math.floor(dur % 60);
                                return minutes + ":" + (seconds < 10 ? "0" : "") + seconds;
                            }
                            font.pixelSize: Theme.fontSizeSmall * 0.9 * userScale
                            color: Theme.surfaceVariantText
                        }
                    }
                }
            }
        }
    }


}
