import Cocoa

enum State: Equatable {
    case idle
    case busy
    case error
}

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    private var blinkStick: BlinkStick?
    private var statusItem: StatusItem?
    private var audioInput: AudioInput?
    private var state: State = .error

    func applicationDidFinishLaunching(_: Notification) {
        statusItem = StatusItem()
        audioInput = AudioInput{ self.setState($0 ? .busy : .idle) }
        render()

        blinkStick = BlinkStick()
        DispatchQueue.main.async {
            self.audioInput?.startListener()
        }
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
}
