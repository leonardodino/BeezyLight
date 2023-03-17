import Foundation

public extension Notification.Name {
    static let deviceIsRunningSomewhereDidChange = Self("deviceIsRunningSomewhereDidChange")
}


final class AudioInput {
    private var devices: Set<AudioDevice>
    private var callback: (Bool) -> Void
    
    init(_ callback: @escaping (Bool) -> Void) {
        self.devices = Set()
        self.callback = callback
    }

    private func updateDeviceList() {
        let input = try? AudioDevice.devices().filter({ try $0.supportsInput() })
        guard let input else { return }
        let inputs = Set(input)
        if (self.devices == inputs) { return }

        let added = inputs.subtracting(self.devices)
        added.forEach { device in
            try? device.whenSelectorChanges(.isRunningSomewhere) { _ in
                NotificationCenter.default.post(name: .deviceIsRunningSomewhereDidChange, object: nil)
            }
        }

        self.devices = inputs
    }
    
    private lazy var listener = Debouncer(delay: 0.5) { [weak self] in
        guard let self else { return }
        let isRunningSomewhere = try? self.devices.contains { try $0.isRunningSomewhere() }
        self.callback(isRunningSomewhere ?? false)
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
