import Cocoa
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var overlayWindows: [NSScreen: NSWindow] = [:]
    private var currentDimPercent: Int = 0
    private var updateTimer: Timer?
    private var trackedWindowID: CGWindowID?
    private var dimColor: NSColor = .black
    private var dimmingMode: Int = 0 // 0: exclude window, 1: screen wide

    private let minWindowWidth: CGFloat = 200
    private let minWindowHeight: CGFloat = 200

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupStatusItem()
        setupKeyboardShortcuts()

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(frontmostAppChanged),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
    }

    private func selectBestWindow(for pid: pid_t) -> (CGWindowID, CGRect)? {
        let options = CGWindowListOption([.optionOnScreenOnly, .excludeDesktopElements])
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }

        let candidates = windowList.compactMap { window -> (id: CGWindowID, layer: Int, area: CGFloat, rect: CGRect)? in
            guard let windowPID = window[kCGWindowOwnerPID as String] as? pid_t, windowPID == pid,
                  let layer = window[kCGWindowLayer as String] as? Int, layer >= 0,
                  let alpha = window[kCGWindowAlpha as String] as? CGFloat, alpha > 0,
                  let bounds = window[kCGWindowBounds as String] as? [String: CGFloat],
                  let x = bounds["X"], let y = bounds["Y"],
                  let width = bounds["Width"], width >= minWindowWidth,
                  let height = bounds["Height"], height >= minWindowHeight,
                  let windowID = window[kCGWindowNumber as String] as? CGWindowID else {
                return nil
            }
            let area = width * height
            let rect = CGRect(x: x, y: y, width: width, height: height)
            return (id: windowID, layer: layer, area: area, rect: rect)
        }

        let sorted = candidates.sorted { a, b in
            if a.layer != b.layer {
                return a.layer < b.layer
            }
            return a.area > b.area
        }

        return sorted.first.map { ($0.id, $0.rect) }
    }
    
    private func setupKeyboardShortcuts() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.modifierFlags.contains([.command, .option]) else { return event }
            
            switch event.charactersIgnoringModifiers {
            case "d": // Cmd+Opt+D - Toggle dim
                self?.toggleDim()
                return nil
            case "l": // Cmd+Opt+L - Lock window
                self?.lockToWindow()
                return nil
            case "u": // Cmd+Opt+U - Unlock window
                self?.unlockWindow()
                return nil
            case "[": // Cmd+Opt+[ - Decrease dim
                self?.adjustDim(by: -5)
                return nil
            case "]": // Cmd+Opt+] - Increase dim
                self?.adjustDim(by: 5)
                return nil
            default:
                return event
            }
        }
    }
    
    @objc private func toggleDim() {
        if currentDimPercent > 0 {
            applyDim(percent: 0)
        } else {
            applyDim(percent: 80)
        }
    }
    
    private func adjustDim(by delta: Int) {
        let newPercent = max(0, min(100, currentDimPercent + delta))
        applyDim(percent: newPercent)
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem.button {
            if let resourcePath = Bundle.module.resourcePath,
               let image = NSImage(contentsOfFile: resourcePath + "/curtain.png") {
                image.size = NSSize(width: 18, height: 18)
                image.isTemplate = true
                button.image = image
            } else {
                button.title = "🎭"
            }
        }

        let menu = NSMenu()
        
        let offItem = NSMenuItem(title: "Off", action: #selector(setDim(_:)), keyEquivalent: "")
        offItem.tag = 0
        menu.addItem(offItem)
        
        for percent in [95, 90, 80, 70, 60] {
            let item = NSMenuItem(title: "\(percent)% Dim", action: #selector(setDim(_:)), keyEquivalent: "")
            item.tag = percent
            menu.addItem(item)
        }
        
        menu.addItem(.separator())
        
        let colorMenu = NSMenu()
        let colorItem = NSMenuItem(title: "Dim Color", action: nil, keyEquivalent: "")
        
        let blackItem = NSMenuItem(title: "Black", action: #selector(setColor(_:)), keyEquivalent: "")
        blackItem.tag = 0
        colorMenu.addItem(blackItem)
        
        let blueItem = NSMenuItem(title: "Blue Light Filter", action: #selector(setColor(_:)), keyEquivalent: "")
        blueItem.tag = 1
        colorMenu.addItem(blueItem)
        
        let sepiaItem = NSMenuItem(title: "Sepia", action: #selector(setColor(_:)), keyEquivalent: "")
        sepiaItem.tag = 2
        colorMenu.addItem(sepiaItem)
        
        let grayItem = NSMenuItem(title: "Gray", action: #selector(setColor(_:)), keyEquivalent: "")
        grayItem.tag = 3
        colorMenu.addItem(grayItem)
        
        colorMenu.items.forEach { $0.target = self }
        colorItem.submenu = colorMenu
        menu.addItem(colorItem)

        menu.addItem(.separator())

        let modeMenu = NSMenu()
        let modeItem = NSMenuItem(title: "Dimming Mode", action: nil, keyEquivalent: "")

        let singleItem = NSMenuItem(title: "Exclude Window", action: #selector(setDimmingMode(_:)), keyEquivalent: "")
        singleItem.tag = 0
        modeMenu.addItem(singleItem)

        let screenWideItem = NSMenuItem(title: "Screen Wide", action: #selector(setDimmingMode(_:)), keyEquivalent: "")
        screenWideItem.tag = 1
        modeMenu.addItem(screenWideItem)

        modeMenu.items.forEach { $0.target = self }
        modeItem.submenu = modeMenu
        menu.addItem(modeItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Lock to Current Window", action: #selector(lockToWindow), keyEquivalent: "l"))
        menu.addItem(NSMenuItem(title: "Unlock Window", action: #selector(unlockWindow), keyEquivalent: "u"))
        menu.addItem(.separator())
        
        let launchItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchItem.state = isLaunchAtLoginEnabled() ? .on : .off
        menu.addItem(launchItem)
        
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))
        
        menu.items.forEach { $0.target = self }
        statusItem.menu = menu
    }

    @objc private func setDim(_ sender: NSMenuItem) {
        applyDim(percent: sender.tag)
    }
    
    @objc private func setColor(_ sender: NSMenuItem) {
        switch sender.tag {
        case 0: dimColor = .black
        case 1: dimColor = NSColor(red: 1.0, green: 0.7, blue: 0.4, alpha: 1.0) // Warm/orange
        case 2: dimColor = NSColor(red: 0.9, green: 0.8, blue: 0.6, alpha: 1.0) // Sepia
        case 3: dimColor = .gray
        default: dimColor = .black
        }

        if currentDimPercent > 0 {
            updateOverlay()
        }
    }

    @objc private func setDimmingMode(_ sender: NSMenuItem) {
        dimmingMode = sender.tag
        if currentDimPercent > 0 {
            updateOverlay()
        }
    }
    
    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        let newState = !isLaunchAtLoginEnabled()
        UserDefaults.standard.set(newState, forKey: "LaunchAtLogin")
        sender.state = newState ? .on : .off
        
        if newState {
            showLaunchAtLoginInstructions()
        }
    }
    
    private func isLaunchAtLoginEnabled() -> Bool {
        return UserDefaults.standard.bool(forKey: "LaunchAtLogin")
    }
    
    private func showLaunchAtLoginInstructions() {
        let alert = NSAlert()
        alert.messageText = "Launch at Login"
        alert.informativeText = "To enable launch at login:\n1. Open System Settings > General > Login Items\n2. Click the '+' button\n3. Select TransparentApple from Applications"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    @objc private func lockToWindow() {
        guard let frontmost = NSWorkspace.shared.frontmostApplication else { return }

        let frontmostPID = frontmost.processIdentifier

        if let (windowID, _) = selectBestWindow(for: frontmostPID) {
            trackedWindowID = windowID
            if currentDimPercent > 0 {
                updateOverlay()
            }
        }
    }
    
    @objc private func unlockWindow() {
        trackedWindowID = nil
        if currentDimPercent > 0 {
            updateOverlay()
        }
    }

    @objc private func frontmostAppChanged() {
        if currentDimPercent > 0 {
            updateOverlay()
        }
    }

    private func applyDim(percent: Int) {
        currentDimPercent = percent
        
        updateTimer?.invalidate()
        updateTimer = nil
        
        if percent > 0 {
            updateOverlay()
            updateTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
                self?.updateOverlay()
            }
        } else {
            clearOverlay()
        }
    }
    
    private func updateOverlay() {
        guard currentDimPercent > 0 else {
            clearOverlay()
            return
        }
        
        let opacity = CGFloat(currentDimPercent) / 100.0
        let options = CGWindowListOption([.optionOnScreenOnly, .excludeDesktopElements])
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            createOverlay(excludingFrame: nil, opacity: opacity)
            return
        }
        
        var targetFrame: CGRect?
        var foundTrackedWindow = false
        
        if let trackedID = trackedWindowID {
            // Look for the tracked window
            for window in windowList {
                guard let windowID = window[kCGWindowNumber as String] as? CGWindowID else { continue }
                
                if windowID == trackedID {
                    if let bounds = window[kCGWindowBounds as String] as? [String: CGFloat],
                       let x = bounds["X"], let y = bounds["Y"],
                       let width = bounds["Width"], let height = bounds["Height"] {
                        targetFrame = CGRect(x: x, y: y, width: width, height: height)
                        foundTrackedWindow = true
                    }
                    break
                }
            }
            
            // If tracked window no longer exists, clear it
            if !foundTrackedWindow {
                trackedWindowID = nil
            }
        }
        
        // If no tracked window or it wasn't found, use frontmost
        if trackedWindowID == nil {
            guard let frontmost = NSWorkspace.shared.frontmostApplication else {
                createOverlay(excludingFrame: nil, opacity: opacity)
                return
            }

            let frontmostPID = frontmost.processIdentifier

            if let (_, rect) = selectBestWindow(for: frontmostPID) {
                targetFrame = rect
            } else {
                createOverlay(excludingFrame: nil, opacity: opacity)
                return
            }
        }
        
        let excludeFrame = dimmingMode == 0 ? targetFrame : nil
        createOverlay(excludingFrame: excludeFrame, opacity: opacity)
    }
    
    private func createOverlay(excludingFrame: CGRect?, opacity: CGFloat) {
        for screen in NSScreen.screens {
            let screenFrame = screen.frame
            
            if let existing = overlayWindows[screen] {
                // Update existing window
                if let excluded = excludingFrame, screen == NSScreen.main {
                    existing.backgroundColor = .clear
                    let contentView = OverlayView(frame: screenFrame)
                    contentView.excludedFrame = excluded
                    contentView.dimColor = dimColor
                    contentView.dimOpacity = opacity
                    existing.contentView = contentView
                } else {
                    existing.contentView = nil
                    existing.backgroundColor = dimColor.withAlphaComponent(opacity)
                }
                existing.orderFrontRegardless()
            } else {
                // Create new window
                let overlay = NSWindow(
                    contentRect: screenFrame,
                    styleMask: .borderless,
                    backing: .buffered,
                    defer: false,
                    screen: screen
                )
                
                if let excluded = excludingFrame, screen == NSScreen.main {
                    overlay.backgroundColor = .clear
                    let contentView = OverlayView(frame: screenFrame)
                    contentView.excludedFrame = excluded
                    contentView.dimColor = dimColor
                    contentView.dimOpacity = opacity
                    overlay.contentView = contentView
                } else {
                    overlay.backgroundColor = dimColor.withAlphaComponent(opacity)
                }
                
                overlay.isOpaque = false
                overlay.level = .floating
                overlay.ignoresMouseEvents = true
                overlay.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
                
                overlay.orderFrontRegardless()
                overlayWindows[screen] = overlay
            }
        }
    }
    
    private func clearOverlay() {
        overlayWindows.values.forEach { $0.orderOut(nil) }
    }

    @objc private func quit() {
        updateTimer?.invalidate()
        overlayWindows.values.forEach { $0.close() }
        overlayWindows.removeAll()
        NSApp.terminate(nil)
    }
}

class OverlayView: NSView {
    var excludedFrame: CGRect?
    var dimOpacity: CGFloat = 0.8
    var dimColor: NSColor = .black
    
    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        context.setFillColor(dimColor.withAlphaComponent(dimOpacity).cgColor)
        context.fill(bounds)
        
        if let excluded = excludedFrame {
            let screenHeight = NSScreen.main?.frame.height ?? 0
            let flippedY = screenHeight - excluded.origin.y - excluded.height
            let flippedFrame = CGRect(x: excluded.origin.x, y: flippedY, 
                                     width: excluded.width, height: excluded.height)
            
            context.setBlendMode(.clear)
            context.fill(flippedFrame)
        }
    }
}

private var appDelegateInstance: AppDelegate?

@main
struct Main {
    static func main() {
        let app = NSApplication.shared
        appDelegateInstance = AppDelegate()
        app.delegate = appDelegateInstance
        app.run()
    }
}
