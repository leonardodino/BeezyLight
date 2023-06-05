import Cocoa
import ServiceManagement

@available(macOS 13.0, *)
final class LaunchAtLogin {
    static let shared = LaunchAtLogin()
    private(set) var menuItem: NSMenuItem
    
    private init() {
        menuItem = NSMenuItem(title: "Launch at login", action: #selector(toggle), keyEquivalent: "")
        menuItem.target = self
        menuItem.state = state
    }
    
    private func set(_ launch: Bool) {
        if launch {
            if SMAppService.mainApp.status == .enabled {
                try? SMAppService.mainApp.unregister()
            }
            try? SMAppService.mainApp.register()
        } else {
            try? SMAppService.mainApp.unregister()
        }
    }
    
    private var state: NSControl.StateValue {
        switch SMAppService.mainApp.status {
            case .notRegistered: return .off
            case .enabled: return .on
            case .requiresApproval: return .mixed
            case .notFound: return .off
            @unknown default: return .off
        }
    }
    
    @objc
    func toggle() {
        switch state {
            case .on: set(false)
            case .off: set(true)
            default: SMAppService.openSystemSettingsLoginItems()
        }
        menuItem.state = state
    }
}

