import Cocoa
import SimplyCoreAudio

enum Icon {
    static let idle = NSImage(systemSymbolName: "mic", accessibilityDescription: nil)
    static let busy = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: nil)
    static let error = NSImage(systemSymbolName: "mic.slash", accessibilityDescription: nil)
}

enum State: Equatable {
    case idle
    case busy
    case error
}

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    private let notificationCenter = NotificationCenter.default
    private var simplyCA: SimplyCoreAudio?
    private var blinkStick: BlinkStick?
    private var statusItem: NSStatusItem?
    private var state: State = .error

    @objc func quit() {
        NSApp.terminate(self)
    }

    @objc func about() {
        NSApp.orderFrontStandardAboutPanel(self)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationDidFinishLaunching(_: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") ?? ""
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "About \(appName)", action: #selector(AppDelegate.about), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(AppDelegate.quit), keyEquivalent: "q"))
        statusItem?.menu = menu
        render()

        simplyCA = SimplyCoreAudio()
        blinkStick = BlinkStick()
        startMicrophoneListener()
    }

    func applicationWillTerminate(_: Notification) {
        blinkStick?.setColor(r: 0, g: 0, b: 0)
    }
}

extension AppDelegate {
    private func render() {
        switch state {
        case .idle:
            statusItem?.button?.image = Icon.idle
            blinkStick?.setColor(r: 0, g: 0, b: 0)
        case .busy:
            statusItem?.button?.image = Icon.busy
            blinkStick?.setColor(r: 255, g: 0, b: 0)
        case .error:
            statusItem?.button?.image = Icon.error
            blinkStick?.setColor(r: 255, g: 0, b: 255)
        }
    }

    private func setState(_ nextState: State) {
        if state != nextState {
            state = nextState
            render()
        }
    }

    private func startMicrophoneListener() {
        let listener = Debouncer(delay: 0.01) { [self] in
            let isBusy = simplyCA?.allInputDevices.contains(where: \.isRunningSomewhere) ?? false
            setState(isBusy ? .busy : .idle)
        }

        listener()
        notificationCenter.addObserver(forName: .deviceIsRunningSomewhereDidChange, object: nil, queue: .main) { _ in
            listener()
        }
    }
}
