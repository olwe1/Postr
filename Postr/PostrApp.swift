import SwiftUI
import AppKit
import LaunchAtLogin

@MainActor
final class MenuBarController: NSObject {
    private let alertState: AlertState
    private let sessionService: SessionService
    
    private let statusItem: NSStatusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover: NSPopover = NSPopover()
    private let menu: NSMenu = NSMenu()
    private var launchAtLoginMenuItem: NSMenuItem?
    
    init(alertState: AlertState, sessionService: SessionService) {
        self.alertState = alertState
        self.sessionService = sessionService
        super.init()
        setupStatusItem()
        setupPopover()
        setupMenu()
    }
    
    private func setupStatusItem() {
        guard let button = statusItem.button else { return }
        
        if let img = NSImage(named: "MenuBarIcon") { img.isTemplate = true; button.image = img }
        else {
            let cfg = NSImage.SymbolConfiguration(pointSize: 18, weight: .regular)
            let img = NSImage(systemSymbolName: "bolt.horizontal.circle", accessibilityDescription: "Nostr")?.withSymbolConfiguration(cfg)
            img?.isTemplate = true
            button.image = img
        }
        
        button.target = self
        button.action = #selector(statusItemClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }
    
    private func setupPopover() {
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 340, height: 420)
        popover.contentViewController = buildContentViewController()
    }
    
    private func setupMenu() {
        menu.removeAllItems()
        // Launch at startup
        let launchItem = NSMenuItem(title: "Launch at startup", action: #selector(toggleLaunchAtLogin(_:)), keyEquivalent: "")
        launchItem.target = self
        launchItem.state = LaunchAtLogin.isEnabled ? .on : .off
        menu.addItem(launchItem)
        self.launchAtLoginMenuItem = launchItem

        // Close app
        menu.addItem(NSMenuItem.separator())
        let closeItem = NSMenuItem(title: "Close", action: #selector(quitApp), keyEquivalent: "")
        closeItem.target = self
        menu.addItem(closeItem)
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        LaunchAtLogin.isEnabled.toggle()
        sender.state = LaunchAtLogin.isEnabled ? .on : .off
    }
    
    private func buildContentViewController() -> NSViewController {
        let content = ContentView()
            .environmentObject(alertState)
            .environmentObject(sessionService)
            .frame(width: 320)
            .padding()
        return NSHostingController(rootView: content)
    }
    
    @objc private func statusItemClicked(_ sender: Any?) {
        guard let event = NSApp.currentEvent, let button = statusItem.button else {
            togglePopover(sender)
            return
        }
        switch event.type {
        case .rightMouseUp:
            self.launchAtLoginMenuItem?.state = LaunchAtLogin.isEnabled ? .on : .off
            statusItem.menu = menu
            button.performClick(nil)
            DispatchQueue.main.async { self.statusItem.menu = nil }
            return
        default:
            togglePopover(sender)
        }
    }
    
    @objc private func togglePopover(_ sender: Any?) {
        if popover.isShown {
            popover.performClose(sender)
        } else if let button = statusItem.button {
            popover.contentViewController = buildContentViewController()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let alertState = AlertState()
    let sessionService = SessionService()
    
    private var menuBarController: MenuBarController!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBarController = MenuBarController(alertState: alertState, sessionService: sessionService)
    }
}

@main
struct PostrApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}
