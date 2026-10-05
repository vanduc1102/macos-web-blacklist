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
    
    private struct DynamicCodingKey: CodingKey {
        var stringValue: String
        var intValue: Int?
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { return nil }
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
        self.iconName = (try? container.decode(String.self, forKey: .iconName)) ?? "globe"
        self.isEnabled = (try? container.decode(Bool.self, forKey: .isEnabled)) ?? true
        self.isCustom = (try? container.decode(Bool.self, forKey: .isCustom)) ?? false
        
        // Decode domains: array of strings, single string, or alternate "domain" key
        var decodedDomains: [String] = []
        if let list = try? container.decode([String].self, forKey: .domains) {
            decodedDomains = list
        } else if let single = try? container.decode(String.self, forKey: .domains) {
            decodedDomains = [single]
        } else {
            let altContainer = try decoder.container(keyedBy: DynamicCodingKey.self)
            if let single = try? altContainer.decode(String.self, forKey: DynamicCodingKey(stringValue: "domain")!) {
                decodedDomains = [single]
            } else if let list = try? altContainer.decode([String].self, forKey: DynamicCodingKey(stringValue: "domain")!) {
                decodedDomains = list
            }
        }
        
        guard !decodedDomains.isEmpty else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "No domain or domains found"))
        }
        self.domains = decodedDomains
        
        if let nameStr = try? container.decode(String.self, forKey: .name), !nameStr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            self.name = nameStr
        } else {
            self.name = decodedDomains.first ?? "Custom Site"
        }
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
    
    // MARK: - Import / Export Types & Methods
    
    public enum ImportMode: Equatable {
        case merge
        case replace
    }
    
    public enum ImportError: LocalizedError, Equatable {
        case emptyOrInvalidData
        case noValidSitesFound
        
        public var errorDescription: String? {
            switch self {
            case .emptyOrInvalidData:
                return "The selected file is empty or cannot be read."
            case .noValidSitesFound:
                return "No valid website domains were found in the selected file."
            }
        }
    }
    
    /// Encodes a list of BlockedSite objects into pretty-printed, sorted JSON data
    public static func exportToJSONData(sites: [BlockedSite]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(sites)
    }
    
    /// Parses imported file data (supports full BlockedSite JSON, domain string array JSON, name-domain dict JSON, or plain text / hosts format)
    public static func parseImport(data: Data) throws -> [BlockedSite] {
        guard !data.isEmpty else {
            throw ImportError.emptyOrInvalidData
        }
        
        // 1. Try decoding as full [BlockedSite] JSON
        if let sites = try? JSONDecoder().decode([BlockedSite].self, from: data), !sites.isEmpty {
            var validatedSites: [BlockedSite] = []
            for site in sites {
                let normalizedDomains = site.domains.flatMap { normalizeDomain($0) }
                let deduped = Array(Set(normalizedDomains)).sorted()
                if !deduped.isEmpty {
                    var cleanSite = site
                    cleanSite.domains = deduped
                    validatedSites.append(cleanSite)
                }
            }
            if !validatedSites.isEmpty {
                return validatedSites
            }
        }
        
        // 2. Try decoding as JSON array of domain strings: ["facebook.com", "tiktok.com"]
        if let stringArray = try? JSONDecoder().decode([String].self, from: data), !stringArray.isEmpty {
            var sites: [BlockedSite] = []
            var seenDomains = Set<String>()
            for str in stringArray {
                let normalized = normalizeDomain(str)
                guard !normalized.isEmpty else { continue }
                let apex = normalized.first(where: { !$0.hasPrefix("www.") }) ?? normalized.first!
                if !seenDomains.contains(apex) {
                    seenDomains.insert(apex)
                    sites.append(BlockedSite(
                        name: apex,
                        iconName: "globe",
                        domains: normalized,
                        isEnabled: true,
                        isCustom: true
                    ))
                }
            }
            if !sites.isEmpty {
                return sites
            }
        }
        
        // 3. Try decoding as JSON dictionary [String: [String]] (e.g. {"Social": ["facebook.com"]})
        if let dict = try? JSONDecoder().decode([String: [String]].self, from: data), !dict.isEmpty {
            var sites: [BlockedSite] = []
            for (name, domainList) in dict {
                let normalized = domainList.flatMap { normalizeDomain($0) }
                let deduped = Array(Set(normalized)).sorted()
                if !deduped.isEmpty {
                    sites.append(BlockedSite(
                        name: name,
                        iconName: "globe",
                        domains: deduped,
                        isEnabled: true,
                        isCustom: true
                    ))
                }
            }
            if !sites.isEmpty {
                return sites
            }
        }
        
        // 4. Try parsing as plain text lines (hosts file, adblock list, or one domain per line)
        if let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) {
            let lines = text.components(separatedBy: .newlines)
            var sites: [BlockedSite] = []
            var seenApexDomains = Set<String>()
            
            for rawLine in lines {
                var line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
                // Skip empty lines and comment lines
                if line.isEmpty || line.hasPrefix("#") || line.hasPrefix("//") || line.hasPrefix("!") {
                    continue
                }
                
                // Remove inline comments
                if let commentIndex = line.firstIndex(of: "#") {
                    line = String(line[..<commentIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
                }
                
                // Tokenize words
                let tokens = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                for token in tokens {
                    // Skip IP addresses from /etc/hosts format
                    if token == "0.0.0.0" || token == "127.0.0.1" || token == "::1" || token == "localhost" {
                        continue
                    }
                    let normalized = normalizeDomain(token)
                    guard !normalized.isEmpty else { continue }
                    
                    let apex = normalized.first(where: { !$0.hasPrefix("www.") }) ?? normalized.first!
                    if !seenApexDomains.contains(apex) {
                        seenApexDomains.insert(apex)
                        sites.append(BlockedSite(
                            name: apex,
                            iconName: "globe",
                            domains: normalized,
                            isEnabled: true,
                            isCustom: true
                        ))
                    }
                }
            }
            if !sites.isEmpty {
                return sites
            }
        }
        
        throw ImportError.noValidSitesFound
    }
    
    /// Merges imported sites into an existing site list without duplicates
    public static func merge(existing: [BlockedSite], imported: [BlockedSite]) -> [BlockedSite] {
        var result = existing
        
        for imp in imported {
            let impDomainSet = Set(imp.domains.map { $0.lowercased() })
            let impNameLower = imp.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            
            // Check if matches existing site by name or domain overlap
            if let matchIndex = result.firstIndex(where: { existingSite in
                let existingDomainSet = Set(existingSite.domains.map { $0.lowercased() })
                if !existingDomainSet.isDisjoint(with: impDomainSet) {
                    return true
                }
                let existingNameLower = existingSite.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                return !existingNameLower.isEmpty && existingNameLower == impNameLower
            }) {
                // Merge domains into existing site
                var mergedDomains = Set(result[matchIndex].domains)
                for d in imp.domains {
                    mergedDomains.formUnion(normalizeDomain(d))
                }
                result[matchIndex].domains = Array(mergedDomains).sorted()
            } else {
                // Add as new custom site
                var newSite = imp
                newSite.isCustom = true
                if result.contains(where: { $0.id == newSite.id }) {
                    newSite.id = UUID()
                }
                var allDomains: Set<String> = []
                for d in newSite.domains {
                    allDomains.formUnion(normalizeDomain(d))
                }
                newSite.domains = Array(allDomains).sorted()
                result.append(newSite)
            }
        }
        
        return result
    }
    
    /// Replaces the current site list with the imported sites, ensuring unique IDs and normalized domains
    public static func replace(existing: [BlockedSite], imported: [BlockedSite]) -> [BlockedSite] {
        var result: [BlockedSite] = []
        var usedIds = Set<UUID>()
        
        for var site in imported {
            if usedIds.contains(site.id) {
                site.id = UUID()
            }
            usedIds.insert(site.id)
            
            var allDomains: Set<String> = []
            for d in site.domains {
                allDomains.formUnion(normalizeDomain(d))
            }
            site.domains = Array(allDomains).sorted()
            result.append(site)
        }
        
        return result
    }
}
