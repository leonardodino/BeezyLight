import Cocoa

enum Icon {
    static let idle = NSImage(systemSymbolName: "mic", accessibilityDescription: nil)
    static let busy = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: nil)
    static let error = NSImage(systemSymbolName: "mic.slash", accessibilityDescription: nil)
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var audioListenerId = -1
    var blinkStick: BlinkStick?
    var statusItem: NSStatusItem?

    @objc func quit() {
        NSApplication.shared.terminate(self)
    }

    func applicationDidFinishLaunching(_: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(AppDelegate.quit), keyEquivalent: "q"))
        statusItem?.menu = menu
        statusItem?.button?.image = Icon.error

        blinkStick = BlinkStick()

        updateMicStatus()
        audioListenerId = Audio.shared.addDeviceStateListener { [weak self] in
            self?.updateMicStatus()
        }
    }

    private func updateMicStatus() {
        print(
            """
            isRunning: \(Audio.shared.isRunning.description)
            device: \(Audio.shared.inputDeviceName ?? "nil")
            """
        )

        if Audio.shared.inputDevice == nil {
            statusItem?.button?.image = Icon.error
            blinkStick?.setColor(r: 255, g: 0, b: 255)
        } else if Audio.shared.isRunning {
            statusItem?.button?.image = Icon.busy
            blinkStick?.setColor(r: 255, g: 0, b: 0)
        } else {
            statusItem?.button?.image = Icon.idle
            blinkStick?.setColor(r: 0, g: 0, b: 0)
        }
    }

    func applicationWillTerminate(_: Notification) {
        blinkStick?.setColor(r: 0, g: 0, b: 0)
        Audio.shared.removeDeviceStateListener(listenerId: audioListenerId)
    }
}
