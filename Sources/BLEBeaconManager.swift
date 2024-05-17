import Foundation
import AppKit
import CoreBluetooth

final class BLEBeaconManager {
    static private let menuItemPrefix = "Bluetooth Settings…"
    static let shared = BLEBeaconManager()
    private var started = false
    private var bleBeacon: BLEBeacon?
    private(set) var menuItem: NSMenuItem
    
    private init() {
        menuItem = NSMenuItem(title: Self.menuItemPrefix, action: #selector(menuItemClick), keyEquivalent: "")
        menuItem.target = self
        updateMenuItemAttributes()
    }
    
    private func parse(_ input: String?) -> UUID? {
        return UUID(uuidString: input?.uppercased().trimmingCharacters(in: .whitespacesAndNewlines) ?? "")
    }
    
    private func getSavedValue() -> UUID? {
        return parse(UserDefaults.standard.string(for: .uuid))
    }
    
    private func set(_ uuid: UUID?) {
        guard bleBeacon?.id != uuid else { return }
        bleBeacon?.stop()
        guard let uuid else {
            bleBeacon = nil
            updateMenuItemAttributes()
            return UserDefaults.standard.remove(key: .uuid)
        }
        UserDefaults.standard.set(uuid.uuidString, for: .uuid)
        bleBeacon = BLEBeacon(uuid) { [weak self] _ in
            self?.updateMenuItemAttributes()
        }
        if started { start() }
    }
}

// MARK: public methods
extension BLEBeaconManager {
    func load() {
        if let uuid = getSavedValue() { set(uuid) }
    }
    
    func start() {
        started = true
        bleBeacon?.start()
    }
    
    func stop() {
        started = false
        bleBeacon?.stop()
    }
}


// MARK: menu item internals
extension BLEBeaconManager {
    private enum MenuItemClickAction {
        case openSystemSettings
        case showSettingsModal
        case showUnknownAlert
    }
    
    private var menuItemTitle: NSAttributedString? {
        let title = NSMutableAttributedString(string: "\(Self.menuItemPrefix)\n", attributes: [:])
        title.append(NSAttributedString(string: "Status: \(bleBeacon?.status ?? "Pending configuration")", attributes: [
            NSAttributedString.Key.font: NSFont.menuBarFont(ofSize: 10),
            NSAttributedString.Key.foregroundColor: NSColor.textColor.withAlphaComponent(0.5),
        ]))
        return title
    }
    
    private var menuItemImage: NSImage? {
        switch bleBeacon?.state ?? .unknown {
            case .unknown: return NSImage(named: NSImage.statusNoneName)
            case .resetting: return NSImage(named: NSImage.statusPartiallyAvailableName)
            case .unsupported: return NSImage(named: NSImage.statusUnavailableName)
            case .unauthorized: return NSImage(named: NSImage.statusUnavailableName)
            case .poweredOff: return NSImage(named: NSImage.statusNoneName)
            case .poweredOn: return NSImage(named: NSImage.statusAvailableName)
            @unknown default: return NSImage(named: NSImage.statusNoneName)
        }
    }
    
    private var menuItemClickAction: MenuItemClickAction {
        guard let bleBeacon else { return .showSettingsModal }
        switch bleBeacon.state {
            case .unknown: return .showUnknownAlert
            case .resetting: return .showUnknownAlert
            case .unsupported: return .openSystemSettings
            case .unauthorized: return .openSystemSettings
            case .poweredOff: return .showSettingsModal
            case .poweredOn: return .showSettingsModal
            @unknown default: return .showUnknownAlert
        }
    }
    
    private func updateMenuItemAttributes() {
        menuItem.attributedTitle = menuItemTitle
        menuItem.image = menuItemImage
    }
    
    @discardableResult
    private func openBluetoothSettings() -> Bool {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Bluetooth")!
        return NSWorkspace.shared.open(url)
    }
    
    @objc
    private func menuItemClick() {
        switch menuItemClickAction {
            case .openSystemSettings: openBluetoothSettings()
            case .showSettingsModal: startAppSettingsModalFlow()
            case .showUnknownAlert: do {}
        }
    }
}

// MARK: modal flow internals
extension BLEBeaconManager {
    private enum SettingsModalResult {
        case uuid(UUID)
        case empty
        case invalid
        case cancelled
    }
    
    private func showSettingsModal() -> SettingsModalResult {
        let field = NSTextField(string: bleBeacon?.id.uuidString.lowercased() ?? "")
        field.placeholderString = "UUID"
        field.autoresizingMask = [.height, .width]
        field.isAutomaticTextCompletionEnabled = false
        field.allowsEditingTextAttributes = false
        field.setContentHuggingPriority(.required, for: .horizontal)
        field.frame.origin = .zero
        field.frame.size = CGSize(width: 230, height: field.intrinsicContentSize.height)
        
        let alert = NSAlert()
        alert.icon = NSImage(named: NSImage.bluetoothTemplateName)
        alert.messageText = "Bluetooth Settings"
        alert.informativeText = "Beacon UUID to broadcast"
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        alert.accessoryView = field
        alert.window.initialFirstResponder = field
        
        guard alert.runModal() == .alertFirstButtonReturn else { return .cancelled }
        let newValue = field.stringValue.trimmingCharacters(in: .whitespaces)
        guard newValue != "" else { return .empty }
        guard let uuid = parse(newValue) else { return .invalid }
        return .uuid(uuid)
    }
    
    private func showErrorModal() -> Bool {
        let alert = NSAlert()
        alert.icon = NSImage(named: NSImage.cautionName)
        alert.messageText = "Parsing Error"
        alert.informativeText = "Please enter a valid UUID string"
        alert.addButton(withTitle: "Try Again")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }
    
    private func showUUIDSuccessModal() {
        let alert = NSAlert()
        alert.icon = NSImage(named: NSImage.infoName)
        alert.messageText = "Sucessfully saved!"
        alert.informativeText = "UUID: \(bleBeacon?.id.uuidString.lowercased() ?? "[unknown]")"
        alert.addButton(withTitle: "Dismiss")
        alert.runModal()
    }
    
    private func showDisableSuccessModal() {
        let alert = NSAlert()
        alert.icon = NSImage(named: NSImage.infoName)
        alert.messageText = "Sucessfully disabled beacon!"
        alert.addButton(withTitle: "Dismiss")
        alert.runModal()
    }
    
    private func startAppSettingsModalFlow() {
        while true {
            switch showSettingsModal() {
                case .uuid(let uuid):
                    set(uuid)
                    return showUUIDSuccessModal()
                case .empty:
                    set(nil)
                    return showDisableSuccessModal()
                case .invalid:
                    if !showErrorModal() { return }
                case .cancelled: return
            }
        }
    }
}


// MARK: convenience extensions
fileprivate extension UUID {
    var data: Data { withUnsafeBytes(of: self.uuid, { Data($0) }) }
}

fileprivate extension UserDefaults {
    enum Key: String, RawRepresentable {
        case uuid
    }
    func string(for key: Key) -> String? {
        return string(forKey: key.rawValue)
    }
    func set(_ value: Any?, for key: Key) {
        return set(value, forKey: key.rawValue)
    }
    func remove(key: Key) {
        return removeObject(forKey: key.rawValue)
    }
}
