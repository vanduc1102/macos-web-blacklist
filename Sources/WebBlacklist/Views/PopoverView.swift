import SwiftUI

@MainActor
public struct PopoverView: View {
    @ObservedObject var store: BlacklistStore
    
    public init(store: BlacklistStore) {
        self.store = store
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // MARK: - Header
            headerSection
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 12)
            
            Divider()
            
            // MARK: - Main Scroll Content
            ScrollView {
                VStack(spacing: 12) {
                    // Big Action Button
                    actionButtonSection
                    
                    // Permission Banner (if not writable)
                    if !store.isHostsWritable {
                        PermissionsBannerView(store: store)
                    }
                    
                    // Status / Error Messages
                    if let error = store.errorMessage {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(error)
                                .font(.system(size: 11))
                                .foregroundColor(.red)
                            Spacer()
                        }
                        .padding(8)
                        .background(Color.red.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    } else if let status = store.statusMessage {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text(status)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding(6)
                        .background(Color.green.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    
                    // Add Site Drawer (if toggled)
                    if store.showingAddSite {
                        AddSiteView(store: store)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    
                    // Blocked Sites Section
                    sitesHeaderSection
                    
                    LazyVStack(spacing: 2) {
                        ForEach(store.sites) { site in
                            SiteRowView(
                                site: site,
                                onToggle: { store.toggleSite(id: site.id) },
                                onDelete: site.isCustom ? { store.removeSite(id: site.id) } : nil
                            )
                        }
                    }
                    
                    Divider()
                        .padding(.vertical, 4)
                    
                    // Auto-Lock Settings
                    autoLockSection
                    
                    // Auto-start at Login Settings
                    launchAtLoginSection
                }
                .padding(14)
            }
            .frame(maxHeight: 400)
            
            Divider()
            
            // MARK: - Footer
            footerSection
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(nsColor: .windowBackgroundColor).opacity(0.4))
        }
        .frame(width: 340)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            store.refreshHostsState()
        }
    }
    
    // MARK: - Subviews
    
    private var headerSection: some View {
        HStack(alignment: .center) {
            HStack(spacing: 8) {
                Image(systemName: store.isLocked ? "lock.shield.fill" : "lock.open.trianglebadge.exclamationmark.fill")
                    .font(.system(size: 18))
                    .foregroundColor(store.isLocked ? .red : .green)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text("Web Blacklist")
                        .font(.system(size: 14, weight: .bold))
                    
                    if store.isLocked {
                        Text("Distracting websites blocked")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    } else if store.remainingSeconds > 0 {
                        let mins = store.remainingSeconds / 60
                        let secs = store.remainingSeconds % 60
                        Text(String(format: "Auto-locking in %02d:%02d", mins, secs))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.orange)
                    } else {
                        Text("Websites currently accessible")
                            .font(.system(size: 10))
                            .foregroundColor(.green)
                    }
                }
            }
            
            Spacer()
            
            // Status Tag
            HStack(spacing: 4) {
                Circle()
                    .fill(store.isLocked ? Color.red : Color.green)
                    .frame(width: 6, height: 6)
                
                Text(store.isLocked ? "LOCKED" : "UNLOCKED")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundColor(store.isLocked ? .red : .green)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background((store.isLocked ? Color.red : Color.green).opacity(0.12))
            .clipShape(Capsule())
        }
    }
    
    private var actionButtonSection: some View {
        Button(action: {
            withAnimation {
                store.toggleLock()
            }
        }) {
            HStack(spacing: 8) {
                if store.isAuthenticating {
                    ProgressView()
                        .controlSize(.small)
                } else if store.isLocked {
                    Image(systemName: "touchid")
                        .font(.system(size: 16, weight: .bold))
                } else {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 14, weight: .bold))
                }
                
                Text(store.isLocked ? "Unlock with Touch ID" : "Lock Blacklist Now")
                    .font(.system(size: 13, weight: .bold))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 38)
            .background(store.isLocked ? Color.blue : Color.red.opacity(0.9))
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
        .disabled(store.isAuthenticating)
    }
    
    private var sitesHeaderSection: some View {
        HStack {
            let activeCount = store.sites.filter { $0.isEnabled }.count
            Text("Blocked Sites (\(activeCount)/\(store.sites.count))")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondary)
            
            Spacer()
            
            Button("All") {
                store.enableAll()
            }
            .buttonStyle(.plain)
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(.accentColor)
            
            Text("•")
                .font(.system(size: 9))
                .foregroundColor(.secondary)
            
            Button("None") {
                store.disableAll()
            }
            .buttonStyle(.plain)
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(.accentColor)
            
            Text("•")
                .font(.system(size: 9))
                .foregroundColor(.secondary)
            
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    store.showingAddSite.toggle()
                }
            }) {
                HStack(spacing: 2) {
                    Image(systemName: store.showingAddSite ? "minus.circle" : "plus.circle")
                    Text(store.showingAddSite ? "Close" : "Add")
                }
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.accentColor)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 4)
    }
    
    private var autoLockSection: some View {
        HStack {
            Image(systemName: "timer")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            
            Text("Auto-lock after:")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            
            Spacer()
            
            Picker("", selection: Binding(
                get: { store.autoLockMinutes },
                set: { store.setAutoLockDuration($0) }
            )) {
                Text("Never").tag(0)
                Text("5 min").tag(5)
                Text("15 min").tag(15)
                Text("30 min").tag(30)
                Text("1 hour").tag(60)
            }
            .pickerStyle(.menu)
            .controlSize(.small)
            .frame(width: 95)
        }
    }
    
    private var launchAtLoginSection: some View {
        HStack {
            Image(systemName: "power.circle.fill")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            
            Text("Launch at Login / Restart:")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            
            Spacer()
            
            Toggle("", isOn: Binding(
                get: { store.launchAtLogin },
                set: { store.setLaunchAtLogin($0) }
            ))
            .toggleStyle(.switch)
            .controlSize(.mini)
            .labelsHidden()
        }
    }
    
    private var footerSection: some View {
        HStack {
            Button(action: {
                store.flushDNS()
            }) {
                HStack(spacing: 3) {
                    Image(systemName: "arrow.clockwise")
                    Text("Flush DNS")
                }
                .font(.system(size: 11))
            }
            .buttonStyle(.borderless)
            .help("Force flush macOS DNS resolver cache")
            
            Spacer()
            
            Button(action: {
                store.resetToDefaults()
            }) {
                Text("Reset Presets")
                    .font(.system(size: 11))
            }
            .buttonStyle(.borderless)
            
            Spacer()
            
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.borderless)
            .font(.system(size: 11))
            .foregroundColor(.secondary)
        }
    }
}
