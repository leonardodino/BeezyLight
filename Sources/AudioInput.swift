import Foundation
import CoreAudio
import Cocoa

public extension Notification.Name {
    static let deviceIsRunningSomewhereDidChange = Self("deviceIsRunningSomewhereDidChange")
}

final class AudioInput {
    private var callback: (Bool) -> Void
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
    
    init(_ callback: @escaping (Bool) -> Void) {
        self.devices = Set()
        self.callback = callback
    }

    private func updateDeviceList() {
        let devices = AudioDevice.inputDevices()
        guard let devices else { return }
        guard devices != self.devices else { return }

        self.devices = devices
    }
    
    private lazy var listener = Debouncer(delay: 0.5) { [weak self] in
        guard let self else { return }
        self.callback(self.devices.isRunningSomewhere() ?? false)
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
