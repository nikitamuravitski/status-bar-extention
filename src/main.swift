import AppKit

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
    var isActive: Bool = false // Track highlight state
    // Store last shown text and color for redraws
    private var lastText: String = ""
    private var lastColor: NSColor = .systemBlue
    
    // Configurable appearance constants
    private let font = NSFont.systemFont(ofSize: 12, weight: .bold)
    private let margin: CGFloat = 2
    private let maxHeight: CGFloat = 21
    private let extraHorizontalPadding: CGFloat = 6
    private let cornerRadius: CGFloat = 3
    private let horizontalTextPadding: CGFloat = 8
    
    func show(text: String, color: NSColor) {
        lastText = text
        lastColor = color
        if statusItem == nil {
            statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            menu = NSMenu()
            let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
            quitItem.target = self
            menu?.addItem(quitItem)
            menu?.delegate = self
        }
        updateButton()
    }
    
    // Calculate all relevant sizes for the button, colored rect, and text
    private func calculateLayout(for text: String) -> (buttonSize: NSSize, colorRect: NSRect, textRect: NSRect, textAttr: NSAttributedString) {
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        let attrTitle = NSAttributedString(
            string: text,
            attributes: [
                .font: font,
                .paragraphStyle: style
            ]
        )
        let textSize = attrTitle.size()
        let colorWidth = textSize.width + 2 * horizontalTextPadding
        let colorHeight = maxHeight - 2 * margin
        let buttonWidth = colorWidth + margin * 2 + extraHorizontalPadding * 2
        let buttonHeight = maxHeight
        let buttonSize = NSSize(width: buttonWidth, height: buttonHeight)
        let colorRect = NSRect(x: margin + extraHorizontalPadding, y: margin, width: colorWidth, height: colorHeight)
        let textRect = NSRect(
            x: colorRect.origin.x + horizontalTextPadding,
            y: colorRect.origin.y + (colorHeight - textSize.height) / 2,
            width: textSize.width,
            height: textSize.height
        )
        return (buttonSize, colorRect, textRect, attrTitle)
    }
    
    // Draw the button image with knockout text and highlight state
    private func drawButtonImage(text: String, color: NSColor, isActive: Bool) -> NSImage {
        let (buttonSize, colorRect, textRect, attrTitle) = calculateLayout(for: text)
        let image = NSImage(size: buttonSize)
        image.lockFocus()
        // Highlighted background if active
        let bgColor: NSColor = isActive ? color.highlight(withLevel: 0.2) ?? color : color
        bgColor.setFill()
        NSBezierPath(roundedRect: colorRect, xRadius: cornerRadius, yRadius: cornerRadius).fill()
        // Draw text as transparent (knockout)
        NSGraphicsContext.current?.cgContext.saveGState()
        NSGraphicsContext.current?.cgContext.setBlendMode(.destinationOut)
        attrTitle.draw(in: textRect)
        NSGraphicsContext.current?.cgContext.restoreGState()
        image.unlockFocus()
        return image
    }
    
    // Update the button's appearance
    private func updateButton() {
        guard let button = statusItem?.button else { return }
        let image = drawButtonImage(text: lastText, color: lastColor, isActive: isActive)
        let (buttonSize, _, _, _) = calculateLayout(for: lastText)
        button.image = image
        button.imagePosition = .imageOnly
        button.title = ""
        button.wantsLayer = true
        button.layer?.backgroundColor = NSColor.clear.cgColor
        button.layer?.borderWidth = 0
        button.layer?.cornerRadius = cornerRadius
        button.layer?.masksToBounds = true
        button.setFrameSize(buttonSize)
        // Manual menu handling
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
        isActive = true
        updateButton()
        let point = NSPoint(x: 0, y: button.bounds.height + 4)
        menu.popUp(positioning: nil, at: point, in: button)
    }
    
    func menuWillOpen(_ menu: NSMenu) {
        isActive = true
        updateButton()
    }
    func menuDidClose(_ menu: NSMenu) {
        isActive = false
        updateButton()
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
