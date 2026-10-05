import Foundation
import Combine
import SwiftUI
import LocalAuthentication
import UniformTypeIdentifiers

@MainActor
public final class BlacklistStore: ObservableObject {
    public static let shared = BlacklistStore()
    
    // Published states
    @Published public var isLocked: Bool = false
    @Published public var sites: [BlockedSite] = []
    @Published public var isHostsWritable: Bool = false
    @Published public var isTouchIDAvailable: Bool = false
    @Published public var isAuthenticating: Bool = false
    @Published public var isShowingFileDialog: Bool = false
    @Published public var launchAtLogin: Bool = false
    @Published public var autoLockMinutes: Int = 0
    @Published public var remainingSeconds: Int = 0
    @Published public var errorMessage: String?
    @Published public var statusMessage: String?
    
    // UI state for Add Site sheet/drawer
    @Published public var showingAddSite: Bool = false
    @Published public var newSiteDomain: String = ""
    @Published public var newSiteName: String = ""
    
    private var autoLockTimer: AnyCancellable?
    private let sitesStorageKey = "web_blacklist_saved_sites_v1"
    private let autoLockStorageKey = "web_blacklist_autolock_minutes_v1"
    
    private init() {
        self.isTouchIDAvailable = TouchIDManager.shared.isBiometricAvailable
        self.isHostsWritable = HostsManager.shared.isHostsWritable
        self.launchAtLogin = LaunchAtLoginManager.shared.isEnabled
        
        loadSavedSites()
        loadPreferences()
        
        // Detect current hosts file state
        let activeInHosts = HostsManager.shared.isBlacklistActive()
        self.isLocked = activeInHosts
    }
    
    public func refreshHostsState() {
        self.isHostsWritable = HostsManager.shared.isHostsWritable
        self.isLocked = HostsManager.shared.isBlacklistActive()
        self.launchAtLogin = LaunchAtLoginManager.shared.isEnabled
    }
    
    public func toggleLaunchAtLogin() {
        setLaunchAtLogin(!launchAtLogin)
    }
    
    public func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try LaunchAtLoginManager.shared.setEnabled(enabled)
            self.launchAtLogin = LaunchAtLoginManager.shared.isEnabled
            self.statusMessage = enabled ? "Auto-start at login enabled" : "Auto-start at login disabled"
        } catch {
            self.errorMessage = "Failed to update auto-start: \(error.localizedDescription)"
            self.launchAtLogin = LaunchAtLoginManager.shared.isEnabled
        }
    }
    
    // MARK: - Lock / Unlock Actions
    
    /// Locks the blacklist, blocking all enabled sites in /etc/hosts
    public func lock() {
        errorMessage = nil
        do {
            try HostsManager.shared.applyBlacklist(sites: sites)
            isLocked = true
            stopAutoLockTimer()
            statusMessage = "Websites locked and blocked"
        } catch {
            errorMessage = "Failed to lock: \(error.localizedDescription)"
        }
    }
    
    /// Requests Touch ID authentication to unlock the blacklist
    public func unlockWithTouchID() {
        errorMessage = nil
        isAuthenticating = true
        
        TouchIDManager.shared.authenticate(reason: "Touch ID to unlock Web Blacklist and access sites") { [weak self] result in
            Task { @MainActor in
                guard let self = self else { return }
                self.isAuthenticating = false
                
                switch result {
                case .success:
                    do {
                        try HostsManager.shared.removeBlacklist()
                        self.isLocked = false
                        self.statusMessage = "Blacklist unlocked with Touch ID"
                        self.startAutoLockTimerIfNeeded()
                    } catch {
                        self.errorMessage = "Failed to unlock /etc/hosts: \(error.localizedDescription)"
                    }
                case .failure(let error):
                    let nsError = error as NSError
                    // Don't show error banner if user voluntarily cancelled
                    if nsError.domain == LAErrorDomain && (
                        nsError.code == LAError.userCancel.rawValue ||
                        nsError.code == LAError.appCancel.rawValue ||
                        nsError.code == LAError.systemCancel.rawValue
                    ) {
                        return
                    }
                    self.errorMessage = "Authentication failed: \(error.localizedDescription)"
                }
            }
        }
    }
    
    /// Toggle lock state
    public func toggleLock() {
        if isLocked {
            unlockWithTouchID()
        } else {
            lock()
        }
    }
    
    // MARK: - Site Management
    
    public func toggleSite(id: UUID) {
        if let index = sites.firstIndex(where: { $0.id == id }) {
            sites[index].isEnabled.toggle()
            saveSites()
            
            // If currently locked, refresh the active hosts file
            if isLocked {
                try? HostsManager.shared.applyBlacklist(sites: sites)
            }
        }
    }
    
    public func addCustomSite(name: String, domainInput: String) {
        let normalized = BlockedSite.normalizeDomain(domainInput)
        guard !normalized.isEmpty else {
            errorMessage = "Please enter a valid domain (e.g. example.com)"
            return
        }
        
        let siteName = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? normalized.first! : name
        let newSite = BlockedSite(
            name: siteName,
            iconName: "globe",
            domains: normalized,
            isEnabled: true,
            isCustom: true
        )
        
        sites.append(newSite)
        saveSites()
        
        if isLocked {
            try? HostsManager.shared.applyBlacklist(sites: sites)
        }
        statusMessage = "Added \(siteName)"
    }
    
    public func removeSite(id: UUID) {
        sites.removeAll(where: { $0.id == id })
        saveSites()
        
        if isLocked {
            try? HostsManager.shared.applyBlacklist(sites: sites)
        }
    }
    
    public func enableAll() {
        for i in 0..<sites.count {
            sites[i].isEnabled = true
        }
        saveSites()
        if isLocked {
            try? HostsManager.shared.applyBlacklist(sites: sites)
        }
    }
    
    public func disableAll() {
        for i in 0..<sites.count {
            sites[i].isEnabled = false
        }
        saveSites()
        if isLocked {
            try? HostsManager.shared.applyBlacklist(sites: sites)
        }
    }
    
    public func resetToDefaults() {
        sites = BlockedSite.loadPresets()
        saveSites()
        if isLocked {
            try? HostsManager.shared.applyBlacklist(sites: sites)
        }
        statusMessage = "Reset to presets from sites.json"
    }
    
    // MARK: - Export and Import
    
    /// Exports the current list of sites to a specified file URL as JSON
    public func exportSites(to url: URL) throws {
        let data = try BlockedSite.exportToJSONData(sites: sites)
        try data.write(to: url, options: .atomic)
    }
    
    /// Displays a native macOS save panel to export the sites list to a JSON file
    public func exportSitesToFile() {
        isShowingFileDialog = true
        defer { isShowingFileDialog = false }
        
        let panel = NSSavePanel()
        panel.title = "Export Website Blacklist"
        panel.prompt = "Export"
        panel.nameFieldStringValue = "web-blacklist-export.json"
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        
        NSApp.activate(ignoringOtherApps: true)
        let response = panel.runModal()
        
        guard response == .OK, let url = panel.url else { return }
        
        do {
            try exportSites(to: url)
            self.statusMessage = "Exported \(sites.count) websites to \(url.lastPathComponent)"
            self.errorMessage = nil
        } catch {
            self.errorMessage = "Failed to export: \(error.localizedDescription)"
        }
    }
    
    /// Imports a list of BlockedSite objects using the specified ImportMode (merge or replace)
    public func importSites(_ imported: [BlockedSite], mode: BlockedSite.ImportMode) -> Int {
        switch mode {
        case .merge:
            self.sites = BlockedSite.merge(existing: sites, imported: imported)
        case .replace:
            self.sites = BlockedSite.replace(existing: sites, imported: imported)
        }
        
        saveSites()
        
        if isLocked {
            try? HostsManager.shared.applyBlacklist(sites: sites)
        }
        
        return self.sites.count
    }
    
    /// Imports sites from a file URL with a specified mode
    public func importSites(from url: URL, mode: BlockedSite.ImportMode) throws -> Int {
        let data = try Data(contentsOf: url)
        let parsed = try BlockedSite.parseImport(data: data)
        guard !parsed.isEmpty else {
            throw BlockedSite.ImportError.noValidSitesFound
        }
        return importSites(parsed, mode: mode)
    }
    
    /// Displays a native macOS open panel to select and import a file (JSON or TXT/hosts), then prompts merge vs replace
    public func importSitesFromFile() {
        isShowingFileDialog = true
        defer { isShowingFileDialog = false }
        
        let panel = NSOpenPanel()
        panel.title = "Import Website Blacklist"
        panel.prompt = "Import"
        panel.allowedContentTypes = [.json, .plainText]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        
        NSApp.activate(ignoringOtherApps: true)
        let response = panel.runModal()
        
        guard response == .OK, let url = panel.url else { return }
        
        do {
            let data = try Data(contentsOf: url)
            let parsed = try BlockedSite.parseImport(data: data)
            guard !parsed.isEmpty else {
                self.errorMessage = "No valid websites found in \(url.lastPathComponent)"
                return
            }
            
            let totalDomains = parsed.reduce(0) { $0 + $1.domains.count }
            
            let alert = NSAlert()
            alert.messageText = "Import Websites"
            alert.informativeText = "Found \(parsed.count) website(s) (\(totalDomains) domain(s)) in '\(url.lastPathComponent)'.\n\nWould you like to merge with your current list or replace all existing websites?"
            alert.addButton(withTitle: "Merge (Keep Current)")
            alert.addButton(withTitle: "Replace All")
            alert.addButton(withTitle: "Cancel")
            alert.alertStyle = .informational
            
            let alertResponse = alert.runModal()
            if alertResponse == .alertFirstButtonReturn {
                // Merge
                _ = self.importSites(parsed, mode: .merge)
                self.statusMessage = "Merged \(parsed.count) site(s) from \(url.lastPathComponent)"
                self.errorMessage = nil
            } else if alertResponse == .alertSecondButtonReturn {
                // Replace
                _ = self.importSites(parsed, mode: .replace)
                self.statusMessage = "Replaced list with \(parsed.count) site(s) from \(url.lastPathComponent)"
                self.errorMessage = nil
            }
        } catch {
            self.errorMessage = "Failed to import: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Auto-Lock Timer
    
    public func setAutoLockDuration(_ minutes: Int) {
        autoLockMinutes = minutes
        UserDefaults.standard.set(minutes, forKey: autoLockStorageKey)
        
        if !isLocked && minutes > 0 {
            startAutoLockTimerIfNeeded()
        } else {
            stopAutoLockTimer()
        }
    }
    
    private func startAutoLockTimerIfNeeded() {
        stopAutoLockTimer()
        guard autoLockMinutes > 0, !isLocked else { return }
        
        remainingSeconds = autoLockMinutes * 60
        autoLockTimer = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                if self.remainingSeconds > 1 {
                    self.remainingSeconds -= 1
                } else {
                    self.stopAutoLockTimer()
                    self.lock()
                    self.statusMessage = "Auto-locked after timer expired"
                }
            }
    }
    
    private func stopAutoLockTimer() {
        autoLockTimer?.cancel()
        autoLockTimer = nil
        remainingSeconds = 0
    }
    
    // MARK: - Permissions & DNS
    
    public func requestDirectPermissions() {
        HostsManager.shared.grantDirectWritePermissions { [weak self] result in
            Task { @MainActor in
                guard let self = self else { return }
                switch result {
                case .success:
                    self.isHostsWritable = true
                    self.statusMessage = "Touch ID direct access granted!"
                case .failure(let error):
                    self.errorMessage = "Permission setup cancelled or failed: \(error.localizedDescription)"
                }
            }
        }
    }
    
    public func flushDNS() {
        HostsManager.shared.flushDNS()
        statusMessage = "macOS DNS Cache flushed"
    }
    
    // MARK: - Persistence
    
    private func saveSites() {
        if let data = try? JSONEncoder().encode(sites) {
            UserDefaults.standard.set(data, forKey: sitesStorageKey)
        }
    }
    
    private func loadSavedSites() {
        if let data = UserDefaults.standard.data(forKey: sitesStorageKey),
           let saved = try? JSONDecoder().decode([BlockedSite].self, from: data),
           !saved.isEmpty {
            self.sites = saved
        } else {
            self.sites = BlockedSite.loadPresets()
        }
    }
    
    private func loadPreferences() {
        self.autoLockMinutes = UserDefaults.standard.integer(forKey: autoLockStorageKey)
    }
}
