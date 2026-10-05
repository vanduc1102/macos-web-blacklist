import Foundation
import Combine
import SwiftUI

@MainActor
public final class BlacklistStore: ObservableObject {
    public static let shared = BlacklistStore()
    
    // Published states
    @Published public var isLocked: Bool = false
    @Published public var sites: [BlockedSite] = []
    @Published public var isHostsWritable: Bool = false
    @Published public var isTouchIDAvailable: Bool = false
    @Published public var isAuthenticating: Bool = false
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
        
        loadSavedSites()
        loadPreferences()
        
        // Detect current hosts file state
        let activeInHosts = HostsManager.shared.isBlacklistActive()
        self.isLocked = activeInHosts
    }
    
    public func refreshHostsState() {
        self.isHostsWritable = HostsManager.shared.isHostsWritable
        self.isLocked = HostsManager.shared.isBlacklistActive()
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
                    // If user cancelled, don't show an intrusive error
                    let nsError = error as NSError
                    if nsError.domain == "com.apple.LocalAuthentication" && nsError.code == -2 {
                        // User cancelled
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
        sites = BlockedSite.defaultPresets
        saveSites()
        if isLocked {
            try? HostsManager.shared.applyBlacklist(sites: sites)
        }
        statusMessage = "Reset to default presets"
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
            self.sites = BlockedSite.defaultPresets
        }
    }
    
    private func loadPreferences() {
        self.autoLockMinutes = UserDefaults.standard.integer(forKey: autoLockStorageKey)
    }
}
