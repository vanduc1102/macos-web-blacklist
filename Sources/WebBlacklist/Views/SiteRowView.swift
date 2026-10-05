import SwiftUI

public struct SiteRowView: View {
    public let site: BlockedSite
    public let onToggle: () -> Void
    public let onDelete: (() -> Void)?
    
    public init(site: BlockedSite, onToggle: @escaping () -> Void, onDelete: (() -> Void)? = nil) {
        self.site = site
        self.onToggle = onToggle
        self.onDelete = onDelete
    }
    
    public var body: some View {
        HStack(spacing: 10) {
            Image(systemName: site.iconName)
                .font(.system(size: 14))
                .foregroundColor(site.isEnabled ? .primary : .secondary)
                .frame(width: 22, height: 22)
                .background(site.isEnabled ? Color.accentColor.opacity(0.15) : Color.gray.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(site.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(site.isEnabled ? .primary : .secondary)
                    
                    if site.isCustom {
                        Text("Custom")
                            .font(.system(size: 9, weight: .semibold))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.blue.opacity(0.15))
                            .foregroundColor(.blue)
                            .clipShape(Capsule())
                    }
                }
                
                Text(site.domains.joined(separator: ", "))
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            
            Spacer()
            
            if let onDelete = onDelete, site.isCustom {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundColor(.red.opacity(0.8))
                }
                .buttonStyle(.plain)
                .help("Delete custom site")
            }
            
            Toggle("", isOn: Binding(
                get: { site.isEnabled },
                set: { _ in onToggle() }
            ))
            .toggleStyle(.switch)
            .controlSize(.mini)
            .labelsHidden()
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(site.isEnabled ? Color(nsColor: .controlBackgroundColor).opacity(0.5) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
