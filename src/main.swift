import Cocoa

// Helper to convert hex string to NSColor
func colorFromHex(_ hex: String) -> NSColor {
    var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
    hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
    var rgb: UInt64 = 0
    Scanner(string: hexSanitized).scanHexInt64(&rgb)
    let r, g, b: CGFloat
    if hexSanitized.count == 6 {
        r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        b = CGFloat(rgb & 0x0000FF) / 255.0
        return NSColor(red: r, green: g, blue: b, alpha: 1.0)
    } else if hexSanitized.count == 3 {
        r = CGFloat((rgb & 0xF00) >> 8) / 15.0
        g = CGFloat((rgb & 0x0F0) >> 4) / 15.0
        b = CGFloat(rgb & 0x00F) / 15.0
        return NSColor(red: r, green: g, blue: b, alpha: 1.0)
    }
    return NSColor.labelColor
}

class StatusBarController: NSObject, NSMenuDelegate {
    var statusItem: NSStatusItem?
    var menu: NSMenu?
    
    func show(text: String, color: NSColor) {
        print("StatusBarController.show called with text: \(text), color: \(color)")
        if statusItem == nil {
            statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            menu = NSMenu()
            let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
            quitItem.target = self
            menu?.addItem(quitItem)
            menu?.delegate = self
            // Do NOT set statusItem?.menu = menu
        }
        guard let button = statusItem?.button else { return }
        // Set styled attributed title
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        let attrTitle = NSAttributedString(
            string: text,
            attributes: [
                .foregroundColor: color,
                .font: NSFont.systemFont(ofSize: 13, weight: .medium),
                .paragraphStyle: style
            ]
        )
        button.attributedTitle = attrTitle
        // Style the button's layer
        button.wantsLayer = true
        button.layer?.backgroundColor = NSColor.clear.cgColor
        button.layer?.borderColor = color.cgColor
        button.layer?.borderWidth = 1
        button.layer?.cornerRadius = 4
        button.layer?.masksToBounds = true
        // Force redraw and size update
        button.sizeToFit()
        let width = button.attributedTitle.size().width + 16 // 8pt padding each side
        let height = button.attributedTitle.size().height + 4 // 2pt padding top/bottom
        button.setFrameSize(NSSize(width: width, height: height))
        // Add click handler to show menu
        button.target = self
        button.action = #selector(showMenu(_:))
    }
    
    @objc func removeEntry() {
        print("StatusBarController.removeEntry called")
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
        }
    }
    
    @objc func quit() {
        NSApp.terminate(nil)
    }
    
    @objc func showMenu(_ sender: Any?) {
        guard let button = statusItem?.button, let menu = menu else { return }
        let event = NSApp.currentEvent
        let point = NSPoint(x: 0, y: button.bounds.height + 4)
        menu.popUp(positioning: nil, at: point, in: button)
    }
    
    func menuWillOpen(_ menu: NSMenu) {
        statusItem?.button?.highlight(false)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    let pipePath = "/tmp/statusbar_control"
    var statusBarController: StatusBarController?
    var pipeFileHandle: FileHandle?
    var listeningQueue: DispatchQueue?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBarController = StatusBarController()
        setupPipe()
    }
    
    func setupPipe() {
        let fm = FileManager.default
        if fm.fileExists(atPath: pipePath) {
            try? fm.removeItem(atPath: pipePath)
        }
        let result = mkfifo(pipePath, 0o666)
        guard result == 0 else {
            print("Failed to create pipe at \(pipePath)")
            return
        }
        listeningQueue = DispatchQueue(label: "pipe-listener")
        listeningQueue?.async { [weak self] in
            self?.listenPipe()
        }
    }
    
    func listenPipe() {
        let fd = open(pipePath, O_RDWR)
        if fd == -1 {
            print("Failed to open pipe for reading and writing")
            return
        }
        let file = fdopen(fd, "r")
        guard let filePtr = file else {
            print("Failed to fdopen pipe")
            return
        }
        while true {
            var linePtr: UnsafeMutablePointer<CChar>? = nil
            var n: Int = 0
            let read = getline(&linePtr, &n, filePtr)
            if read > 0, let linePtr = linePtr {
                let line = String(cString: linePtr).trimmingCharacters(in: .whitespacesAndNewlines)
                if !line.isEmpty {
                    handleCommand(line)
                }
            } else {
                Thread.sleep(forTimeInterval: 0.1)
            }
            if let linePtr = linePtr {
                free(linePtr)
            }
        }
    }
    
    func handleCommand(_ command: String) {
        print("Received command: \(command)")
        let parts = command.components(separatedBy: "|")
        if parts[0] == "add", parts.count >= 3 {
            let text = parts[1]
            let color = colorFromHex(parts[2])
            DispatchQueue.main.async { [weak self] in
                print("Showing status bar entry: \(text) with color \(parts[2])")
                self?.statusBarController?.show(text: text, color: color)
            }
        } else if parts[0] == "remove" {
            DispatchQueue.main.async { [weak self] in
                print("Removing status bar entry")
                self?.statusBarController?.removeEntry()
            }
        } else if parts[0] == "quit" {
            DispatchQueue.main.async {
                print("Quitting app")
                NSApp.terminate(nil)
            }
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
