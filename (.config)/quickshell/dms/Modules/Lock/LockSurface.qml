import QtCore
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import Quickshell.Wayland
import "../../Services" as Services
import "../../Widgets" as Widgets
import "../../Common" as Common
import "../../Common"

WlSessionLockSurface {
	id: root
	
	required property WlSessionLock lock
	required property string sharedPasswordBuffer
	
	signal passwordChanged(string newPassword)
	
	readonly property bool locked: lock && lock.locked
	property real animationTime: 300
	property var easingType: Easing.OutExpo
	
	color: !root.startAnim ? "transparent" : Common.Theme.surface
	Behavior on color { ColorAnimation { duration: animationTime; easing.type: easingType } }
	
	property bool startAnim: false
	property bool exiting: false
	property bool showError: false
	property string errorMessage: ""
	property bool unlocking: false
	property string pamState: ""
	
	function unlock(): void {
		lock.locked = false
	}
	
	// PAM Authentication
	FileView {
		id: pamConfigWatcher
		path: "/etc/pam.d/dankshell"
		printErrors: false
	}

	PamContext {
		id: pam
		config: pamConfigWatcher.loaded ? "dankshell" : "login"
		
		onResponseRequiredChanged: {
			if (!responseRequired) return
			console.log("PAM response required, sending password")
			respond(root.sharedPasswordBuffer)
		}
		
		onCompleted: res => {
			console.log("PAM authentication completed with result:", res)
			if (res === PamResult.Success) {
				console.log("Authentication successful, unlocking")
				root.unlocking = true
				root.showError = false
				passwordBox.text = ""
				root.passwordChanged("")
				root.unlock()
				startAnim = false
				return
			}
			
			console.log("Authentication failed:", res)
			passwordBox.text = ""
			root.passwordChanged("")
			root.showError = true
			
			if (res === PamResult.Error) {
				root.pamState = "error"
				root.errorMessage = "Authentication error - try again"
			} else if (res === PamResult.MaxTries) {
				root.pamState = "max"
				root.errorMessage = "Too many attempts - locked out"
			} else if (res === PamResult.Failed) {
				root.pamState = "fail"
				root.errorMessage = "Incorrect password - try again"
			}
			
			shakeAnim.restart()
			errorTimer.restart()
		}
	}
	
	Timer {
		id: errorTimer
		interval: 4000
		onTriggered: {
			root.pamState = ""
			root.showError = false
		}
	}
	
	// Screenshot background
	ScreencopyView {
		id: background
		anchors.fill: parent
		captureSource: root.screen
		live: false
		layer.enabled: true
		layer.effect: MultiEffect {
			autoPaddingEnabled: false
			blurEnabled: true
			blur: root.startAnim ? 1 : 0
			blurMax: 32
			blurMultiplier: 1
			contrast: root.startAnim ? 0.05 : 0
			saturation: root.startAnim ? 0.1 : 0
			Behavior on blur { NumberAnimation { duration: animationTime; easing.type: easingType } }
			Behavior on contrast { NumberAnimation { duration: animationTime; easing.type: easingType } }
			Behavior on saturation { NumberAnimation { duration: animationTime; easing.type: easingType } }
		}
		scale: root.startAnim ? 1.1 : 1
		Behavior on scale { NumberAnimation { duration: animationTime; easing.type: easingType } }
		rotation: root.startAnim ? 0.25 : 0
		Behavior on rotation {
			NumberAnimation { duration: animationTime; easing.type: easingType }
		}
		Rectangle {
			id: overlayRect
			anchors.fill: parent
			color: Common.Theme.surface
			opacity: root.startAnim ? 0.1 : 0
			Behavior on opacity {
				NumberAnimation { duration: animationTime; easing.type: easingType }
			}
		}
	}
	
	// Audio visualizer (if CavaService is available)
	Loader {
		anchors.bottom: parent.bottom
		anchors.left: parent.left
		anchors.right: parent.right
		height: 200
		opacity: root.startAnim ? 1 : 0
		Behavior on opacity { NumberAnimation { duration: animationTime; easing.type: easingType } }
		
		active: Services.CavaService.cavaAvailable
		
		sourceComponent: Item {
			anchors.fill: parent
			
			Loader {
				active: Services.MprisController.activePlayer?.playbackState === MprisPlaybackState.Playing
				sourceComponent: Component {
					Ref {
						service: Services.CavaService
					}
				}
			}
			
			// Basic visualizer bars
			Repeater {
				model: 32
				Rectangle {
					x: parent.width * (index / 32)
					width: parent.width / 32 - 2
					height: {
						if (Services.CavaService.values && Services.CavaService.values.length > index) {
							const rawLevel = Services.CavaService.values[index] || 0
							const scaledLevel = Math.sqrt(Math.min(Math.max(rawLevel, 0), 100) / 100) * 100
							return (scaledLevel / 100) * 150
						}
						return 0
					}
					anchors.bottom: parent.bottom
					color: Common.Theme.primary
					opacity: 0.6
					
					Behavior on height {
						NumberAnimation {
							duration: 100
							easing.type: Easing.OutCubic
						}
					}
				}
			}
		}
	}
	
	// Clock display (centered)
	Item {
		id: centeredElements
		layer.enabled: true
		layer.effect: MultiEffect {
			shadowEnabled: true
			shadowOpacity: root.startAnim ? 1 : 0
			shadowColor: Common.Theme.shadow
			shadowBlur: 2
			shadowScale: 1
			Behavior on shadowOpacity {
				NumberAnimation { duration: animationTime; easing.type: easingType }
			}
		}
		scale: root.startAnim ? 1 : 0.9
		opacity: root.startAnim ? 1 : 0
		Behavior on scale { NumberAnimation { duration: animationTime; easing.type: easingType } }
		Behavior on opacity { NumberAnimation { duration: animationTime; easing.type: easingType } }

		anchors.centerIn: parent
		implicitWidth: centeredContainer.width + 40
		implicitHeight: centeredContainer.height + 40
		
		ColumnLayout {
			anchors.horizontalCenter: parent.horizontalCenter
			id: centeredContainer
			spacing: 10
			
			ColumnLayout {
				Layout.alignment: Qt.AlignHCenter 
				id: clockContainer
				spacing: 0
				
				Widgets.StyledText { 
					id: timeText
					text: Qt.formatDateTime(new Date(), "h:mm AP")
					font.family: "Outfit ExtraBold"
					color: "white"
					font.pixelSize: 92
					Layout.alignment: Qt.AlignHCenter 
				} 
				
				Widgets.StyledText { 
					id: dateText
					text: Qt.formatDateTime(new Date(), "dddd, dd/MM")
					color: "white"
					font.pixelSize: 32 
					Layout.alignment: Qt.AlignHCenter 
				} 
			}
		}
		
		Timer {
			interval: 1000
			running: true
			repeat: true
			onTriggered: {
				timeText.text = Qt.formatDateTime(new Date(), "h:mm AP")
				dateText.text = Qt.formatDateTime(new Date(), "dddd, dd/MM")
			}
		}
	}

	// Media player display
	Loader {
		anchors.right: loginContainer.left
		anchors.rightMargin: 20
		anchors.bottom: loginContainer.bottom
		
		layer.enabled: true
		layer.effect: MultiEffect {
			shadowEnabled: true
			shadowOpacity: root.startAnim ? 1 : 0
			shadowColor: Common.Theme.shadow
			shadowBlur: 2
			shadowScale: 1
			Behavior on shadowOpacity {
				NumberAnimation { duration: animationTime; easing.type: easingType }
			}
		}
		
		scale: root.startAnim ? 1 : 0.9
		opacity: root.startAnim ? 1 : 0
		Behavior on scale { NumberAnimation { duration: animationTime; easing.type: easingType } }
		Behavior on opacity { NumberAnimation { duration: animationTime; easing.type: easingType } }
		
		active: Services.MprisController.activePlayer !== null
		
		sourceComponent: Widgets.StyledRect {
			implicitWidth: 300
			implicitHeight: mediaLayout.height + 40
			color: Qt.rgba(Common.Theme.surfaceContainer.r, Common.Theme.surfaceContainer.g, Common.Theme.surfaceContainer.b, 0.9)
			radius: 40
			
			ColumnLayout {
				id: mediaLayout
				anchors.centerIn: parent
				width: parent.width - 40
				spacing: 10
				
				RowLayout {
					spacing: 15
					
					Widgets.DankAlbumArt {
						Layout.preferredWidth: 55
						Layout.preferredHeight: 55
						activePlayer: Services.MprisController.activePlayer
						showAnimation: false
					}
					
					ColumnLayout {
						spacing: 5
						Layout.fillWidth: true
						
						Widgets.StyledText {
							text: Services.MprisController.activePlayer?.trackTitle || "No media"
							font.pixelSize: 14
							color: "white"
							Layout.fillWidth: true
							elide: Text.ElideRight
						}
						
						Widgets.StyledText {
							text: Services.MprisController.activePlayer?.trackArtist || ""
							font.pixelSize: 10
							color: Qt.rgba(255, 255, 255, 0.7)
							Layout.fillWidth: true
							elide: Text.ElideRight
						}
					}
				}
				
				RowLayout {
					Layout.fillWidth: true
					Layout.alignment: Qt.AlignHCenter
					spacing: 10
					
					Widgets.DankActionButton {
						iconName: "skip_previous"
						buttonSize: 36
						enabled: Services.MprisController.activePlayer?.canGoPrevious ?? false
						onClicked: Services.MprisController.activePlayer?.previous()
					}
					
					Widgets.DankActionButton {
						iconName: {
							const player = Services.MprisController.activePlayer
							if (!player) return "play_arrow"
							return player.playbackState === MprisPlaybackState.Playing ? "pause" : "play_arrow"
						}
						buttonSize: 36
						onClicked: Services.MprisController.activePlayer?.togglePlaying()
					}
					
					Widgets.DankActionButton {
						iconName: "skip_next"
						buttonSize: 36
						enabled: Services.MprisController.activePlayer?.canGoNext ?? false
						onClicked: Services.MprisController.activePlayer?.next()
					}
				}
			}
		}
	}
	
	// Error message display
	Widgets.StyledRect {
		id: errorCard
		visible: root.showError
		color: Common.Theme.error
		radius: 40
		
		layer.enabled: true
		layer.effect: MultiEffect {
			shadowEnabled: true
			shadowOpacity: root.startAnim && root.showError ? 1 : 0
			shadowColor: Common.Theme.shadow
			shadowBlur: 2
			shadowScale: 1
			Behavior on shadowOpacity {
				NumberAnimation { duration: animationTime; easing.type: easingType }
			}
		}
		
		scale: root.showError ? 1 : 0.9
		opacity: root.showError ? 1 : 0
		Behavior on scale { NumberAnimation { duration: animationTime; easing.type: easingType } }
		Behavior on opacity { NumberAnimation { duration: animationTime; easing.type: easingType } }
		
		anchors.bottom: loginContainer.top
		anchors.bottomMargin: 20
		anchors.left: loginContainer.left
		anchors.right: loginContainer.right
		
		implicitHeight: errorLayout.height + 40
		
		RowLayout {
			id: errorLayout
			anchors.centerIn: parent
			width: parent.width - 40
			spacing: 15
			
			Widgets.DankIcon {
				name: "error"
				color: Common.Theme.onError
				font.pixelSize: 24
			}
			
			ColumnLayout {
				Layout.fillWidth: true
				spacing: 5
				
				Widgets.StyledText {
					text: "Authentication Failed"
					font.pixelSize: 16
					font.weight: Font.Bold
					color: Common.Theme.onError
				}
				
				Widgets.StyledText {
					text: root.errorMessage || "Incorrect password"
					font.pixelSize: 12
					color: Common.Theme.onError
					Layout.fillWidth: true
					wrapMode: Text.Wrap
				}
			}
		}
	}
	
	// Login container
	Item {
		id: loginContainer
		property real shakeOffset: 0
		
		transform: Translate { x: loginContainer.shakeOffset }
		
		SequentialAnimation {
			id: shakeAnim
			NumberAnimation { target: loginContainer; property: "shakeOffset"; to: -10; duration: 50; easing.type: Easing.InOutQuad }
			NumberAnimation { target: loginContainer; property: "shakeOffset"; to: 10; duration: 50; easing.type: Easing.InOutQuad }
			NumberAnimation { target: loginContainer; property: "shakeOffset"; to: -5; duration: 50; easing.type: Easing.InOutQuad }
			NumberAnimation { target: loginContainer; property: "shakeOffset"; to: 5; duration: 50; easing.type: Easing.InOutQuad }
			NumberAnimation { target: loginContainer; property: "shakeOffset"; to: 0; duration: 50; easing.type: Easing.InOutQuad }
		}
		
		layer.enabled: true
		layer.effect: MultiEffect {
			shadowEnabled: true
			shadowOpacity: root.startAnim ? 1 : 0
			shadowColor: Common.Theme.shadow
			shadowBlur: 2
			shadowScale: 1
			Behavior on shadowOpacity {
				NumberAnimation { duration: animationTime; easing.type: easingType }
			}
		}
		
		scale: root.startAnim ? 1 : 0.9
		opacity: root.startAnim ? 1 : 0
		Behavior on scale { NumberAnimation { duration: animationTime; easing.type: easingType } }
		Behavior on opacity { NumberAnimation { duration: animationTime; easing.type: easingType } }

		anchors.bottom: parent.bottom
		anchors.bottomMargin: root.startAnim ? 40 : -80
		Behavior on anchors.bottomMargin { NumberAnimation { duration: animationTime; easing.type: easingType } }

		anchors.horizontalCenter: parent.horizontalCenter
		implicitWidth: rowContainer.width + 40
		implicitHeight: rowContainer.height + 40
		
		Widgets.StyledRect {
			id: loginBG
			color: Qt.rgba(Common.Theme.surfaceContainer.r, Common.Theme.surfaceContainer.g, Common.Theme.surfaceContainer.b, 0.9)
			anchors.fill: parent
			radius: 40
		}

		RowLayout {
			anchors.left: parent.left
			anchors.top: parent.top
			anchors.leftMargin: 20
			anchors.topMargin: 20
			spacing: 20
			id: rowContainer

			Widgets.DankCircularImage {
				Layout.preferredWidth: 55
				Layout.preferredHeight: 55
				imageSource: {
					if (Services.PortalService.profileImage === "") {
						return ""
					}
					if (Services.PortalService.profileImage.startsWith("/")) {
						return "file://" + Services.PortalService.profileImage
					}
					return Services.PortalService.profileImage
				}
				fallbackIcon: "person"
			}

			ColumnLayout {
				id: loginContent
				spacing: 10

				Widgets.DankTextField {
					id: passwordBox
					Layout.preferredWidth: 300
					Layout.preferredHeight: 45
					placeholderText: {
						if (root.unlocking) return "Unlocking..."
						if (pam.active) return "Authenticating..."
						if (root.showError) return "Incorrect password"
						return Quickshell.env("USER")
					}
					focus: true
					echoMode: TextInput.Password
					text: root.sharedPasswordBuffer
					enabled: !pam.active && !root.unlocking

					onTextChanged: {
						root.passwordChanged(text)
					}
					
					onAccepted: {
						if (!pam.active && !root.unlocking && text.length > 0) {
							console.log("Enter pressed, starting PAM authentication")
							pam.start()
						}
					}
					
					Keys.onPressed: (event) => {
						if (event.key === Qt.Key_Escape) {
							text = ""
							root.passwordChanged("")
							event.accepted = true
						}
						if (pam.active) {
							event.accepted = true
						}
					}
				}
			}
		}
	}

	// System tray and controls
	Item {
		anchors.left: loginContainer.right
		anchors.leftMargin: 20
		anchors.bottom: loginContainer.bottom
		
		layer.enabled: true
		layer.effect: MultiEffect {
			shadowEnabled: true
			shadowOpacity: root.startAnim ? 1 : 0
			shadowColor: Common.Theme.shadow
			shadowBlur: 2
			shadowScale: 1
			Behavior on shadowOpacity {
				NumberAnimation { duration: animationTime; easing.type: easingType }
			}
		}
		
		scale: root.startAnim ? 1 : 0.9
		opacity: root.startAnim ? 1 : 0
		Behavior on scale { NumberAnimation { duration: animationTime; easing.type: easingType } }
		Behavior on opacity { NumberAnimation { duration: animationTime; easing.type: easingType } }

		implicitWidth: rightContainer.width + 40
		implicitHeight: rightContainer.height + 40
				
		Widgets.StyledRect {
			color: Qt.rgba(Common.Theme.surfaceContainer.r, Common.Theme.surfaceContainer.g, Common.Theme.surfaceContainer.b, 0.9)
			anchors.fill: parent
			radius: 40
		}
		
		RowLayout {
			id: rightContainer
			anchors.left: parent.left
			anchors.top: parent.top
			anchors.leftMargin: 20
			anchors.topMargin: 20
			spacing: 20
			
			Widgets.StyledRect {
				implicitWidth: innerContainer.width + 40
				implicitHeight: 55
				color: Common.Theme.surfaceContainerHighest
				radius: 20
				
				RowLayout {
					id: innerContainer
					anchors.verticalCenter: parent.verticalCenter
					anchors.left: parent.left
					anchors.leftMargin: 20
					spacing: 25
					
					// Network status
					Widgets.DankIcon {
						Layout.alignment: Qt.AlignVCenter
						name: Services.NetworkService.networkStatus === "ethernet" ? "lan" : Services.NetworkService.wifiSignalIcon
						color: "white"
						font.pixelSize: 20
						visible: Services.NetworkService.networkStatus !== "disconnected"
					}
					
					MouseArea {
						anchors.fill: parent
						anchors.leftMargin: -10
						anchors.rightMargin: -10
						cursorShape: Qt.PointingHandCursor
						onClicked: {
							// Toggle WiFi
							if (Services.NetworkService.networkStatus === "wifi") {
								Services.NetworkService.setWifiEnabled(!Services.NetworkService.wifiEnabled)
							}
						}
					}
					
					// Bluetooth status
					Widgets.DankIcon {
						Layout.alignment: Qt.AlignVCenter
						name: "bluetooth"
						color: "white"
						font.pixelSize: 20
						visible: Services.BluetoothService.available && Services.BluetoothService.enabled
					}
					
					MouseArea {
						anchors.fill: parent
						anchors.leftMargin: -10
						anchors.rightMargin: -10
						cursorShape: Qt.PointingHandCursor
						onClicked: {
							// Toggle Bluetooth
							Services.BluetoothService.powered = !Services.BluetoothService.powered
						}
					}
					
					// Volume
					Widgets.DankIcon {
						Layout.alignment: Qt.AlignVCenter
						name: {
							if (!Services.AudioService.sink?.audio) {
								return "volume_up"
							}
							if (Services.AudioService.sink.audio.muted || Services.AudioService.sink.audio.volume === 0) {
								return "volume_off"
							}
							if (Services.AudioService.sink.audio.volume * 100 < 33) {
								return "volume_down"
							}
							return "volume_up"
						}
						color: "white"
						font.pixelSize: 20
						visible: Services.AudioService.sink && Services.AudioService.sink.audio
					}
					
					MouseArea {
						anchors.fill: parent
						anchors.leftMargin: -10
						anchors.rightMargin: -10
						cursorShape: Qt.PointingHandCursor
						onClicked: {
							// Toggle mute
							if (Services.AudioService.sink?.audio) {
								Services.AudioService.sink.audio.muted = !Services.AudioService.sink.audio.muted
							}
						}
					}
					
					// Battery status
					Loader {
						Layout.alignment: Qt.AlignVCenter
						active: Services.BatteryService.batteryAvailable
						
						sourceComponent: Widgets.DankIcon {
							name: {
								if (Services.BatteryService.isCharging) {
									return "battery_charging_full"
								}
								if (Services.BatteryService.batteryLevel >= 95) {
									return "battery_full"
								}
								if (Services.BatteryService.batteryLevel >= 70) {
									return "battery_5_bar"
								}
								if (Services.BatteryService.batteryLevel >= 40) {
									return "battery_3_bar"
								}
								return "battery_1_bar"
							}
							color: Services.BatteryService.isCharging ? Common.Theme.primary : "white"
							font.pixelSize: 20
						}
					}
				}
			}
			
			Widgets.StyledRect {
				implicitWidth: 55
				implicitHeight: 55
				color: Common.Theme.surfaceContainerHighest
				radius: 20
				
				Widgets.DankIcon {
					name: 'power_settings_new'
					color: Common.Theme.error
					font.pixelSize: 26
					anchors.centerIn: parent
				}
				
				MouseArea {
					anchors.fill: parent
					cursorShape: Qt.PointingHandCursor
					onClicked: {
						powerMenu.visible = !powerMenu.visible
					}
				}
			}
		}
	}

	// Notification panel popup
	Rectangle {
		id: notificationPanel
		visible: false
		anchors.fill: parent
		color: Qt.rgba(0, 0, 0, 0.6)
		z: 1001
		
		MouseArea {
			anchors.fill: parent
			onClicked: notificationPanel.visible = false
		}
		
		Widgets.StyledRect {
			anchors.right: parent.right
			anchors.top: parent.top
			anchors.rightMargin: 40
			anchors.topMargin: 40
			width: 400
			height: Math.min(parent.height - 80, notifLayout.height + 60)
			color: Common.Theme.surfaceContainer
			radius: 30
			
			ColumnLayout {
				id: notifLayout
				anchors.fill: parent
				anchors.margins: 20
				spacing: 15
				
				RowLayout {
					Layout.fillWidth: true
					spacing: 10
					
					Widgets.StyledText {
						text: "Notifications"
						font.pixelSize: 24
						font.weight: Font.Bold
						color: Common.Theme.onSurface
						Layout.fillWidth: true
					}
					
					Widgets.DankActionButton {
						iconName: "close"
						buttonSize: 32
						onClicked: notificationPanel.visible = false
					}
				}
				
				Rectangle {
					Layout.fillWidth: true
					Layout.preferredHeight: 1
					color: Common.Theme.outline
					opacity: 0.3
				}
				
				Widgets.DankFlickable {
					Layout.fillWidth: true
					Layout.fillHeight: true
					contentHeight: notificationList.height
					
					ColumnLayout {
						id: notificationList
						width: parent.width
						spacing: 10
						
						Repeater {
							model: Services.NotificationService.notifications
							
							delegate: Widgets.StyledRect {
								Layout.fillWidth: true
								implicitHeight: notifContent.height + 30
								color: Common.Theme.surfaceContainerHighest
								radius: 15
								
								RowLayout {
									id: notifContent
									anchors.fill: parent
									anchors.margins: 15
									spacing: 12
									
									Widgets.DankIcon {
										name: modelData.appIcon || "notifications"
										color: Common.Theme.primary
										font.pixelSize: 24
										Layout.alignment: Qt.AlignTop
									}
									
									ColumnLayout {
										Layout.fillWidth: true
										spacing: 5
										
										Widgets.StyledText {
											text: modelData.summary || "Notification"
											font.pixelSize: 14
											font.weight: Font.Bold
											color: Common.Theme.onSurface
											Layout.fillWidth: true
											wrapMode: Text.Wrap
										}
										
										Widgets.StyledText {
											text: modelData.body || ""
											font.pixelSize: 12
											color: Common.Theme.onSurfaceVariant
											Layout.fillWidth: true
											wrapMode: Text.Wrap
											visible: text.length > 0
										}
									}
									
									Widgets.DankActionButton {
										iconName: "close"
										buttonSize: 28
										Layout.alignment: Qt.AlignTop
										onClicked: {
											modelData.close()
										}
									}
								}
							}
						}
						
						// Empty state
						Item {
							Layout.fillWidth: true
							Layout.preferredHeight: 150
							visible: Services.NotificationService.notifications.length === 0
							
							ColumnLayout {
								anchors.centerIn: parent
								spacing: 10
								
								Widgets.DankIcon {
									name: "notifications_off"
									color: Common.Theme.onSurfaceVariant
									font.pixelSize: 48
									Layout.alignment: Qt.AlignHCenter
									opacity: 0.5
								}
								
								Widgets.StyledText {
									text: "No notifications"
									font.pixelSize: 16
									color: Common.Theme.onSurfaceVariant
									Layout.alignment: Qt.AlignHCenter
									opacity: 0.7
								}
							}
						}
					}
				}
				
				Widgets.DankButton {
					Layout.fillWidth: true
					Layout.preferredHeight: 40
					text: "Clear All"
					iconName: "delete_sweep"
					backgroundColor: Common.Theme.error
					textColor: "white"
					visible: Services.NotificationService.notifications.length > 0
					onClicked: {
						// Clear all notifications
						for (let i = Services.NotificationService.notifications.length - 1; i >= 0; i--) {
							Services.NotificationService.notifications[i].close()
						}
						notificationPanel.visible = false
					}
				}
			}
		}
	}

	// Power menu popup
	Rectangle {
		id: powerMenu
		visible: false
		anchors.fill: parent
		color: Qt.rgba(0, 0, 0, 0.6)
		z: 1000
		
		MouseArea {
			anchors.fill: parent
			onClicked: powerMenu.visible = false
		}
		
		Widgets.StyledRect {
			anchors.centerIn: parent
			width: 300
			height: powerMenuLayout.height + 60
			color: Common.Theme.surfaceContainer
			radius: 30
			
			ColumnLayout {
				id: powerMenuLayout
				anchors.centerIn: parent
				width: parent.width - 40
				spacing: 15
				
				Widgets.StyledText {
					text: "Power Options"
					font.pixelSize: 24
					font.weight: Font.Bold
					color: Common.Theme.onSurface
					Layout.alignment: Qt.AlignHCenter
				}
				
				// Shutdown button
				Widgets.DankButton {
					Layout.fillWidth: true
					Layout.preferredHeight: 50
					text: "Power Off"
					iconName: "power_settings_new"
					backgroundColor: Common.Theme.error
					textColor: "white"
					onClicked: {
						powerMenu.visible = false
						Services.SessionService.poweroff()
					}
				}
				
				// Reboot button
				Widgets.DankButton {
					Layout.fillWidth: true
					Layout.preferredHeight: 50
					text: "Restart"
					iconName: "refresh"
					backgroundColor: Common.Theme.primary
					textColor: "white"
					onClicked: {
						powerMenu.visible = false
						Services.SessionService.reboot()
					}
				}
				
				// Logout button
				Widgets.DankButton {
					Layout.fillWidth: true
					Layout.preferredHeight: 50
					text: "Log Out"
					iconName: "logout"
					backgroundColor: Common.Theme.primary
					textColor: "white"
					onClicked: {
						powerMenu.visible = false
						Services.SessionService.logout()
					}
				}
				
				// Cancel button
				Widgets.DankButton {
					Layout.fillWidth: true
					Layout.preferredHeight: 50
					text: "Cancel"
					iconName: "close"
					backgroundColor: Common.Theme.surfaceVariant
					textColor: "white"
					onClicked: {
						powerMenu.visible = false
					}
				}
			}
		}
	}

	Connections {
		target: lock
		function onLockedChanged() {
			if (!lock.locked) {
				startAnim = false
				exiting = true
			}
		}
	}
	
	Component.onCompleted: {
		startAnim = true
		passwordBox.forceActiveFocus()
	}
}
