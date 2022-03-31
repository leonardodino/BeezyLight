import Cocoa

class StatusItem {
    enum StateIcon {
        case idle
        case busy
        case error
        
        var image: NSImage? {
            switch self {
            case .idle: return NSImage(systemSymbolName: "mic", accessibilityDescription: nil)
            case .busy: return NSImage(systemSymbolName: "mic.fill", accessibilityDescription: nil)
            case .error: return NSImage(systemSymbolName: "mic.slash", accessibilityDescription: nil)
            }
        }
    }
    
    private let instance = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    
    init() {
        let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") ?? ""
        instance.menu = NSMenu([
            NSMenuItem("About \(appName)", action: #selector(AboutWindow.show), target: AboutWindow.shared),
            NSMenuItem("Quit", action: #selector(NSApp.terminate), keyEquivalent: "q"),
        ])
    }
    
    func setIcon(_ icon: StateIcon) {
        instance.button?.image = icon.image
    }
}

fileprivate extension NSMenuItem {
    convenience init(_ title: String, action: Selector, target: AnyObject? = nil, keyEquivalent: String = "") {
        self.init(title: title, action: action, keyEquivalent: keyEquivalent)
        self.target = target
    }
}

fileprivate extension NSMenu {
    convenience init(_ items: [NSMenuItem]) {
        self.init()
        items.forEach { self.addItem($0) }
    }
}
