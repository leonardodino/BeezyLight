import Cocoa
import ServiceManagement

fileprivate extension NSApplication {
    var quitMenuItem: NSMenuItem {
        NSMenuItem(title: "Quit", action: #selector(terminate), keyEquivalent: "q")
    }
}

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
    
    private lazy var menu: NSMenu = {
        let menu = NSMenu()
        menu.addItem(AboutWindow.shared.menuItem)
        if #available(macOS 13.0, *) {
            menu.addItem(LaunchAtLogin.shared.menuItem)
            menu.addItem(NSMenuItem.separator())
        }
        menu.addItem(NSApplication.shared.quitMenuItem)
        return menu
    }()
    
    init() {
        instance.menu = menu
    }
    
    func setIcon(_ icon: StateIcon) {
        instance.button?.image = icon.image
    }
}
