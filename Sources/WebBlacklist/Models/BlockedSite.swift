import Foundation

public struct BlockedSite: Identifiable, Codable, Equatable {
    public var id: UUID
    public var name: String
    public var iconName: String
    public var domains: [String]
    public var isEnabled: Bool
    public var isCustom: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case iconName
        case domains
        case isEnabled
        case isCustom
    }
    
    public init(
        id: UUID = UUID(),
        name: String,
        iconName: String = "globe",
        domains: [String],
        isEnabled: Bool = true,
        isCustom: Bool = false
    ) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.domains = domains
        self.isEnabled = isEnabled
        self.isCustom = isCustom
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? container.decode(UUID.self, forKey: .id)) ?? UUID()
        self.name = try container.decode(String.self, forKey: .name)
        self.iconName = (try? container.decode(String.self, forKey: .iconName)) ?? "globe"
        self.domains = try container.decode([String].self, forKey: .domains)
        self.isEnabled = (try? container.decode(Bool.self, forKey: .isEnabled)) ?? true
        self.isCustom = (try? container.decode(Bool.self, forKey: .isCustom)) ?? false
    }
    
    /// Normalizes and cleans a domain/URL string into bare hostnames
    public static func normalizeDomain(_ input: String) -> [String] {
        var trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        // Remove scheme if present
        if trimmed.hasPrefix("https://") {
            trimmed = String(trimmed.dropFirst(8))
        } else if trimmed.hasPrefix("http://") {
            trimmed = String(trimmed.dropFirst(7))
        }
        
        // Remove path or query string
        if let slashIndex = trimmed.firstIndex(of: "/") {
            trimmed = String(trimmed[..<slashIndex])
        }
        if let questionIndex = trimmed.firstIndex(of: "?") {
            trimmed = String(trimmed[..<questionIndex])
        }
        if let colonIndex = trimmed.firstIndex(of: ":") {
            trimmed = String(trimmed[..<colonIndex])
        }
        
        trimmed = trimmed.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        
        var results: Set<String> = [trimmed]
        
        // Also add www. or apex domain variant
        if trimmed.hasPrefix("www.") {
            let apex = String(trimmed.dropFirst(4))
            if !apex.isEmpty {
                results.insert(apex)
            }
        } else if !trimmed.contains("localhost") && trimmed.contains(".") {
            results.insert("www." + trimmed)
        }
        
        return Array(results).sorted()
    }
    
    /// Loads presets from JSON file (sites.json), with fallback to defaultPresets
    public static func loadPresets() -> [BlockedSite] {
        // 1. Try App Bundle resources
        if let bundleUrl = Bundle.main.url(forResource: "sites", withExtension: "json"),
           let data = try? Data(contentsOf: bundleUrl),
           let sites = try? JSONDecoder().decode([BlockedSite].self, from: data) {
            return sites
        }
        
        // 2. Try common locations relative to working dir or bundle
        let possiblePaths = [
            "Resources/sites.json",
            "sites.json",
            Bundle.main.bundlePath + "/Contents/Resources/sites.json"
        ]
        
        for path in possiblePaths {
            let url = URL(fileURLWithPath: path)
            if let data = try? Data(contentsOf: url),
               let sites = try? JSONDecoder().decode([BlockedSite].self, from: data) {
                return sites
            }
        }
        
        // 3. Fallback to built-in presets
        return defaultPresets
    }
    
    /// Default presets embedded in code as a fallback
    public static var defaultPresets: [BlockedSite] {
        [
            BlockedSite(
                name: "Facebook & Messenger",
                iconName: "bubble.left.and.bubble.right.fill",
                domains: [
                    "facebook.com", "www.facebook.com", "m.facebook.com", "fb.com", "www.fb.com",
                    "messenger.com", "www.messenger.com", "static.xx.fbcdn.net", "connect.facebook.net"
                ],
                isEnabled: true,
                isCustom: false
            ),
            BlockedSite(
                name: "Instagram",
                iconName: "camera.fill",
                domains: [
                    "instagram.com", "www.instagram.com", "cdninstagram.com", "graph.instagram.com"
                ],
                isEnabled: true,
                isCustom: false
            ),
            BlockedSite(
                name: "Threads",
                iconName: "at",
                domains: [
                    "threads.net", "www.threads.net"
                ],
                isEnabled: true,
                isCustom: false
            ),
            BlockedSite(
                name: "X (Twitter)",
                iconName: "message.fill",
                domains: [
                    "x.com", "www.x.com", "twitter.com", "www.twitter.com", "t.co", "api.twitter.com", "abs.twimg.com"
                ],
                isEnabled: true,
                isCustom: false
            ),
            BlockedSite(
                name: "TikTok",
                iconName: "music.note",
                domains: [
                    "tiktok.com", "www.tiktok.com", "m.tiktok.com", "v.tiktok.com", "byteoversea.com", "ibytedtos.com"
                ],
                isEnabled: true,
                isCustom: false
            ),
            BlockedSite(
                name: "YouTube",
                iconName: "play.rectangle.fill",
                domains: [
                    "youtube.com", "www.youtube.com", "m.youtube.com", "youtu.be", "ytimg.com"
                ],
                isEnabled: true,
                isCustom: false
            ),
            BlockedSite(
                name: "Reddit",
                iconName: "bubble.middle.bottom.fill",
                domains: [
                    "reddit.com", "www.reddit.com", "old.reddit.com", "redd.it", "preview.redd.it"
                ],
                isEnabled: true,
                isCustom: false
            ),
            BlockedSite(
                name: "LinkedIn",
                iconName: "person.2.fill",
                domains: [
                    "linkedin.com", "www.linkedin.com", "licdn.com"
                ],
                isEnabled: true,
                isCustom: false
            ),
            BlockedSite(
                name: "Pinterest",
                iconName: "pin.fill",
                domains: [
                    "pinterest.com", "www.pinterest.com", "pinimg.com"
                ],
                isEnabled: true,
                isCustom: false
            ),
            BlockedSite(
                name: "Twitch",
                iconName: "tv.fill",
                domains: [
                    "twitch.tv", "www.twitch.tv", "ttvnw.net"
                ],
                isEnabled: true,
                isCustom: false
            ),
            BlockedSite(
                name: "Discord",
                iconName: "waveform",
                domains: [
                    "discord.com", "www.discord.com", "discord.gg", "discordapp.com"
                ],
                isEnabled: true,
                isCustom: false
            ),
            BlockedSite(
                name: "Local Distraction Sites",
                iconName: "newspaper.fill",
                domains: [
                    "vnexpress.net", "www.vnexpress.net", "genk.vn", "www.genk.vn", "chotot.com", "www.chotot.com"
                ],
                isEnabled: true,
                isCustom: false
            )
        ]
    }
}
