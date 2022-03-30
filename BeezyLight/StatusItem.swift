import Cocoa

fileprivate func createMenu(_ itemCreators: [(_ menuItem: NSMenuItem) -> Void]) -> NSMenu {
    let menu = NSMenu()
    itemCreators.forEach { createItem in
        let item = NSMenuItem()
        createItem(item)
        menu.addItem(item)
    }
    return menu
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
    
    init() {
        instance.menu = createMenu([{
            let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") ?? ""
            $0.title = "About \(appName)"
            $0.action = #selector(AboutWindow.show)
            $0.target = AboutWindow.shared
        }, {
            $0.title = "Quit"
            $0.keyEquivalent = "q"
            $0.action = #selector(NSApp.terminate)
            $0.target = NSApp
        }])
    }
    
    func setIcon(_ icon: StateIcon) {
        instance.button?.image = icon.image
    }
}
