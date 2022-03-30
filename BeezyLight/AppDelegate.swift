import Cocoa
import SimplyCoreAudio

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
    private var statusItem: StatusItem?
    private var state: State = .error

    func applicationDidFinishLaunching(_: Notification) {
        statusItem = StatusItem()
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
            statusItem?.setIcon(.idle)
            blinkStick?.setColor(r: 0, g: 0, b: 0)
        case .busy:
            statusItem?.setIcon(.busy)
            blinkStick?.setColor(r: 255, g: 0, b: 0)
        case .error:
            statusItem?.setIcon(.error)
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
