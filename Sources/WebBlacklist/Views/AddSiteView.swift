import SwiftUI

public struct AddSiteView: View {
    @ObservedObject var store: BlacklistStore
    
    public init(store: BlacklistStore) {
        self.store = store
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Add Website to Blacklist")
                .font(.system(size: 13, weight: .bold))
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Domain or URL:")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                
                TextField("e.g. reddit.com, vnexpress.net", text: $store.newSiteDomain)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Display Name (optional):")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                
                TextField("e.g. Reddit", text: $store.newSiteName)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
            }
            
            HStack {
                Button("Cancel") {
                    store.newSiteDomain = ""
                    store.newSiteName = ""
                    store.showingAddSite = false
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Spacer()
                
                Button("Add Site") {
                    let domain = store.newSiteDomain.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !domain.isEmpty else { return }
                    store.addCustomSite(name: store.newSiteName, domainInput: domain)
                    store.newSiteDomain = ""
                    store.newSiteName = ""
                    store.showingAddSite = false
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(store.newSiteDomain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.top, 4)
        }
        .padding(12)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}
