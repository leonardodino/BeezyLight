import Foundation
import CoreAudio
import Cocoa

public extension Notification.Name {
    static let deviceIsRunningSomewhereDidChange = Self("deviceIsRunningSomewhereDidChange")
}

final class AudioInput {
    private var callback: (Bool) -> Void
    private var timer: Timer?
    private var devices: Set<AudioDevice> {
        didSet {
            let added = devices.subtracting(oldValue)
            added.forEach { device in
                try? device.whenSelectorChanges(.isRunningSomewhere) { _ in
                    NotificationCenter.default.post(name: .deviceIsRunningSomewhereDidChange, object: nil)
                }
            }
        }
    }
    private var hasBluetooth: Bool {
        didSet {
            guard hasBluetooth != oldValue else { return }

            timer?.invalidate()
            guard hasBluetooth == true else { return }

            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                NotificationCenter.default.post(name: .deviceIsRunningSomewhereDidChange, object: nil)
            }
        }
    }
    
    init(_ callback: @escaping (Bool) -> Void) {
        self.devices = Set()
        self.callback = callback
        self.hasBluetooth = false
    }

    private func updateDeviceList() {
        let devices = AudioDevice.inputDevices()
        guard let devices else { return }
        guard devices != self.devices else { return }

        self.devices = devices
        self.hasBluetooth = devices.contains(where: \.isBluetooh)
    }
    
    private lazy var listener = Debouncer(delay: 0.5) { [weak self] in
        guard let self else { return }
        self.callback(self.isRunningSomewhere)
    }

    func startListener() {
        listener()
        NotificationCenter.default.addObserver(forName: .deviceIsRunningSomewhereDidChange, object: nil, queue: .main) { [weak self] _ in
            self?.listener()
        }
        
        updateDeviceList()
        try? AudioSystemObject.instance.whenSelectorChanges(.devices) { [weak self] _ in
            self?.updateDeviceList()
        }
    }
}

extension AudioInput {
    private func hasOrangeDot() -> Bool {
        let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[CFString: Any]]
        return (windows ?? []).contains { $0[kCGWindowName] as? String == "StatusIndicator" }
    }

    private var isRunningSomewhere: Bool {
        // FB12081267: bluetooth input devices always report that isRunningSomewhere == false
        if hasBluetooth { return hasOrangeDot() }
        return devices.isRunningSomewhere() ?? false
    }
}
