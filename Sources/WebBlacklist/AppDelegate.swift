import AppKit

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    
    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Ensure app behaves as a menu bar accessory application
        NSApp.setActivationPolicy(.accessory)
        
        // Initialize status bar item
        statusBarController = StatusBarController(store: BlacklistStore.shared)
    }
    
    public func applicationWillTerminate(_ notification: Notification) {
        // Cleanup if needed
    }
}
