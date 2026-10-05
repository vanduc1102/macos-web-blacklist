import Foundation
import AppKit
import ServiceManagement

public final class LaunchAtLoginManager {
    public static let shared = LaunchAtLoginManager()
    
    private let userDefaultsKey = "web_blacklist_auto_start_at_login"
    
    private init() {}
    
    /// Checks whether the app is currently configured to launch at login / restart
    public var isEnabled: Bool {
        if #available(macOS 13.0, *) {
            let status = SMAppService.mainApp.status
            if status == .enabled {
                return true
            } else if status == .notRegistered {
                return false
            }
        }
        
        // Fallback: check AppleScript login items or persisted preference
        if isLoginItemConfiguredViaAppleScript() {
            return true
        }
        return UserDefaults.standard.bool(forKey: userDefaultsKey)
    }
    
    /// Registers or unregisters the app from auto-starting at login
    public func setEnabled(_ enabled: Bool) throws {
        UserDefaults.standard.set(enabled, forKey: userDefaultsKey)
        
        var smError: Error?
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    if SMAppService.mainApp.status != .enabled {
                        try SMAppService.mainApp.register()
                    }
                } else {
                    if SMAppService.mainApp.status == .enabled {
                        try SMAppService.mainApp.unregister()
                    }
                }
                return
            } catch {
                smError = error
            }
        }
        
        // Fallback to macOS System Events Login Item (works during dev builds & ad-hoc signed apps)
        configureLoginItemViaAppleScript(enable: enabled)
        
        if let smError = smError, !isLoginItemConfiguredViaAppleScript() && enabled {
            throw smError
        }
    }
    
    /// Checks if "Web Blacklist" exists in the user's Login Items via System Events
    private func isLoginItemConfiguredViaAppleScript() -> Bool {
        let script = "tell application \"System Events\" to get name of every login item"
        var errorInfo: NSDictionary?
        guard let output = NSAppleScript(source: script)?.executeAndReturnError(&errorInfo) else {
            return false
        }
        guard let listStr = output.stringValue else { return false }
        return listStr.contains("Web Blacklist") || listStr.contains("WebBlacklist")
    }
    
    /// Adds or removes the application from macOS Login Items via System Events
    private func configureLoginItemViaAppleScript(enable: Bool) {
        let appBundlePath = Bundle.main.bundlePath
        let script: String
        
        if enable {
            // Check if installed in /Applications or running from local bundle
            let targetPath: String
            if FileManager.default.fileExists(atPath: "/Applications/WebBlacklist.app") {
                targetPath = "/Applications/WebBlacklist.app"
            } else {
                targetPath = appBundlePath
            }
            
            script = """
            tell application "System Events"
                if not (exists (every login item whose name is "Web Blacklist")) then
                    make login item at end with properties {path:"\(targetPath)", hidden:false, name:"Web Blacklist"}
                end if
            end tell
            """
        } else {
            script = """
            tell application "System Events"
                delete (every login item whose name is "Web Blacklist")
            end tell
            """
        }
        
        var errorInfo: NSDictionary?
        NSAppleScript(source: script)?.executeAndReturnError(&errorInfo)
    }
}
