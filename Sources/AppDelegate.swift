import Cocoa

enum State: Equatable {
    case idle
    case busy
    case error
}

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    private var beacon = BLEBeaconManager.shared
    private var statusItem: StatusItem?
    private var audioInput: AudioInput?
    private var state: State = .error

    func applicationDidFinishLaunching(_: Notification) {
        statusItem = StatusItem()
        audioInput = AudioInput{ self.setState($0 ? .busy : .idle) }
        render()

        beacon.load()
        DispatchQueue.main.async {
            self.audioInput?.startListener()
        }
    }
    
    func applicationWillTerminate(_: Notification) {
        beacon.stop()
    }
}

extension AppDelegate {
    private func render() {
        switch state {
            case .idle:
                statusItem?.setIcon(.idle)
                beacon.stop()
            case .busy:
                statusItem?.setIcon(.busy)
                beacon.start()
            case .error:
                statusItem?.setIcon(.error)
                beacon.stop()
        }
    }
    
    private func setState(_ nextState: State) {
        if state != nextState {
            state = nextState
            render()
        }
    }
}
