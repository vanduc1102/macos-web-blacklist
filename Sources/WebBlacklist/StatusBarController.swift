import AppKit
import SwiftUI
import Combine

@MainActor
public final class StatusBarController: NSObject {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private let store: BlacklistStore
    private var cancellables = Set<AnyCancellable>()
    private var eventMonitor: Any?
    
    public init(store: BlacklistStore) {
        self.store = store
        super.init()
        setupStatusItem()
        setupPopover()
        observeStore()
    }
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            updateStatusItemIcon(isLocked: store.isLocked)
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }
    
    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 340, height: 460)
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(rootView: PopoverView(store: store))
    }
    
    private func observeStore() {
        store.$isLocked
            .receive(on: DispatchQueue.main)
            .sink { [weak self] locked in
                self?.updateStatusItemIcon(isLocked: locked)
            }
            .store(in: &cancellables)
    }
    
    private func updateStatusItemIcon(isLocked: Bool) {
        guard let button = statusItem.button else { return }
        
        let symbolName = isLocked ? "lock.shield.fill" : "lock.open.trianglebadge.exclamationmark.fill"
        let fallbackSymbol = isLocked ? "lock.fill" : "lock.open"
        
        var image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Web Blacklist")
        if image == nil {
            image = NSImage(systemSymbolName: fallbackSymbol, accessibilityDescription: "Web Blacklist")
        }
        
        // Configure image rendering
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        let configuredImage = image?.withSymbolConfiguration(config)
        configuredImage?.isTemplate = true
        
        button.image = configuredImage
        button.toolTip = isLocked ? "Web Blacklist: Locked (Social media blocked)" : "Web Blacklist: Unlocked (Sites accessible)"
    }
    
    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        let currentEvent = NSApp.currentEvent
        
        // Right click opens a quick context menu
        if currentEvent?.type == .rightMouseUp {
            showContextMenu()
            return
        }
        
        // Left click toggles the popover
        togglePopover(sender)
    }
    
    public func togglePopover(_ sender: AnyObject?) {
        if popover.isShown {
            closePopover(sender)
        } else {
            showPopover(sender)
        }
    }
    
    private func showPopover(_ sender: AnyObject?) {
        guard let button = statusItem.button else { return }
        store.refreshHostsState()
        
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
        
        // Setup outside click monitor
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self = self else { return }
            if !self.store.isAuthenticating {
                self.closePopover(nil)
            }
        }
    }
    
    private func closePopover(_ sender: AnyObject?) {
        popover.performClose(sender)
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
    
    private func showContextMenu() {
        let menu = NSMenu()
        
        let statusTitle = store.isLocked ? "Status: 🔒 Locked (Blocked)" : "Status: 🔓 Unlocked (Allowed)"
        let statusMenuItem = NSMenuItem(title: statusTitle, action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)
        
        menu.addItem(NSMenuItem.separator())
        
        if store.isLocked {
            let unlockItem = NSMenuItem(title: "Unlock with Touch ID...", action: #selector(contextUnlock), keyEquivalent: "u")
            unlockItem.target = self
            menu.addItem(unlockItem)
        } else {
            let lockItem = NSMenuItem(title: "Lock Now", action: #selector(contextLock), keyEquivalent: "l")
            lockItem.target = self
            menu.addItem(lockItem)
        }
        
        menu.addItem(NSMenuItem.separator())
        
        let flushItem = NSMenuItem(title: "Flush DNS Cache", action: #selector(contextFlushDNS), keyEquivalent: "")
        flushItem.target = self
        menu.addItem(flushItem)
        
        let openItem = NSMenuItem(title: "Open Dashboard...", action: #selector(contextOpenDashboard), keyEquivalent: "o")
        openItem.target = self
        menu.addItem(openItem)
        
        let launchItem = NSMenuItem(title: "Launch at Login", action: #selector(contextToggleLaunchAtLogin), keyEquivalent: "")
        launchItem.target = self
        launchItem.state = store.launchAtLogin ? .on : .off
        menu.addItem(launchItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Quit Web Blacklist", action: #selector(contextQuit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil // Reset so regular left click keeps opening popover
    }
    
    @objc private func contextUnlock() {
        store.unlockWithTouchID()
    }
    
    @objc private func contextLock() {
        store.lock()
    }
    
    @objc private func contextFlushDNS() {
        store.flushDNS()
    }
    
    @objc private func contextToggleLaunchAtLogin() {
        store.toggleLaunchAtLogin()
    }
    
    @objc private func contextOpenDashboard() {
        if let button = statusItem.button {
            showPopover(button)
        }
    }
    
    @objc private func contextQuit() {
        NSApplication.shared.terminate(nil)
    }
}
