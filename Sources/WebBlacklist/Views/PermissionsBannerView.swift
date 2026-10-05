import SwiftUI

public struct PermissionsBannerView: View {
    @ObservedObject var store: BlacklistStore
    
    public init(store: BlacklistStore) {
        self.store = store
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "touchid")
                    .font(.system(size: 18))
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 3) {
                    Text("Enable Instant Touch ID")
                        .font(.system(size: 12, weight: .bold))
                    
                    Text("Grant 1-time write access to /etc/hosts so fingerprint unblocks immediately without password prompts.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            
            HStack {
                Spacer()
                Button(action: {
                    store.requestDirectPermissions()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.shield.fill")
                        Text("Grant One-Time Setup")
                    }
                    .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(10)
        .background(Color.blue.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
        )
    }
}
