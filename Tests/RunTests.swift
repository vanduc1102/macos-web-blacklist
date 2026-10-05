import Foundation

@main
struct RunTests {
    static func main() {
        print("🧪 Running WebBlacklist test suite...")
        
        // 1. Domain normalization
        let d1 = BlockedSite.normalizeDomain("https://facebook.com/messages/123")
        assert(d1.contains("facebook.com"), "Failed to normalize facebook.com")
        assert(d1.contains("www.facebook.com"), "Failed to normalize www.facebook.com")
        
        let d2 = BlockedSite.normalizeDomain("http://www.instagram.com/p/abc?ref=share")
        assert(d2.contains("instagram.com"), "Failed to extract apex instagram.com")
        assert(d2.contains("www.instagram.com"), "Failed to preserve www.instagram.com")
        
        // 2. JSON preset loading
        let loaded = BlockedSite.loadPresets()
        assert(!loaded.isEmpty, "Presets loaded from sites.json must not be empty")
        assert(loaded.contains(where: { $0.name.contains("Facebook") }), "Must contain Facebook")
        
        // 3. Hosts block generation
        let site = BlockedSite(
            name: "Meta",
            domains: ["facebook.com", "instagram.com"],
            isEnabled: true
        )
        let block = HostsManager.shared.generateBlockContent(for: [site])
        assert(block.contains("0.0.0.0 facebook.com"))
        assert(block.contains("::1 facebook.com"))
        assert(block.contains("0.0.0.0 instagram.com"))
        assert(block.contains("::1 instagram.com"))
        assert(block.contains(HostsManager.shared.beginMarker))
        assert(block.contains(HostsManager.shared.endMarker))
        
        // 3. Hosts stripping & preservation
        let hostsData = """
        127.0.0.1 localhost
        ::1 localhost
        192.168.1.50 custom.server.local
        
        """ + block + "\n"
        
        let stripped = HostsManager.shared.stripManagedBlock(from: hostsData)
        assert(stripped.contains("127.0.0.1 localhost"))
        assert(stripped.contains("192.168.1.50 custom.server.local"))
        assert(!stripped.contains("facebook.com"))
        assert(!stripped.contains("instagram.com"))
        assert(!stripped.contains(HostsManager.shared.beginMarker))
        assert(!stripped.contains(HostsManager.shared.endMarker))
        
        // 4. Export sites to JSON data
        let sampleSites = [
            BlockedSite(
                name: "Twitter",
                iconName: "message.fill",
                domains: ["x.com", "twitter.com"],
                isEnabled: true,
                isCustom: false
            ),
            BlockedSite(
                name: "Custom Blog",
                iconName: "globe",
                domains: ["blog.example.com"],
                isEnabled: false,
                isCustom: true
            )
        ]
        
        guard let exportedData = try? BlockedSite.exportToJSONData(sites: sampleSites) else {
            fatalError("Failed to export sites to JSON data")
        }
        guard let jsonString = String(data: exportedData, encoding: .utf8) else {
            fatalError("Exported data is not valid UTF-8 string")
        }
        assert(jsonString.contains("Twitter"), "Exported JSON must contain Twitter")
        assert(jsonString.contains("x.com"), "Exported JSON must contain x.com")
        assert(jsonString.contains("Custom Blog"), "Exported JSON must contain Custom Blog")
        
        // 5. Import from full [BlockedSite] JSON
        let importedSites = try! BlockedSite.parseImport(data: exportedData)
        assert(importedSites.count == 2, "Must import 2 sites from full JSON")
        assert(importedSites[0].name == "Twitter")
        assert(importedSites[1].domains.contains("blog.example.com"))
        
        // 6. Import from JSON array of domain strings
        let jsonArrayString = """
        [
            "https://netflix.com/browse",
            "tiktok.com",
            "www.twitch.tv"
        ]
        """
        let arrayImported = try! BlockedSite.parseImport(data: jsonArrayString.data(using: .utf8)!)
        assert(arrayImported.count == 3, "Must parse 3 sites from string array")
        assert(arrayImported.contains(where: { $0.domains.contains("netflix.com") }))
        assert(arrayImported.contains(where: { $0.domains.contains("tiktok.com") }))
        assert(arrayImported.contains(where: { $0.domains.contains("twitch.tv") }))
        
        // 7. Import from JSON dictionary of categories -> domains
        let jsonDictString = """
        {
            "Video Streaming": ["youtube.com", "vimeo.com"],
            "Shorts": ["tiktok.com"]
        }
        """
        let dictImported = try! BlockedSite.parseImport(data: jsonDictString.data(using: .utf8)!)
        assert(dictImported.count == 2, "Must parse 2 sites from dictionary")
        assert(dictImported.contains(where: { $0.name == "Video Streaming" && $0.domains.contains("youtube.com") }))
        
        // 8. Import from plain text / hosts file format
        let textList = """
        # Distraction sites blocklist
        // Another comment
        ! Adblock syntax comment
        
        0.0.0.0 reddit.com # inline comment
        ::1 reddit.com
        127.0.0.1 old.reddit.com
        https://9gag.com/trending
        chotot.com
        """
        let textImported = try! BlockedSite.parseImport(data: textList.data(using: .utf8)!)
        assert(textImported.count == 4, "Must extract 4 distinct sites (reddit.com, old.reddit.com, 9gag.com, chotot.com), got \(textImported.count)")
        assert(textImported.contains(where: { $0.domains.contains("reddit.com") }))
        assert(textImported.contains(where: { $0.domains.contains("old.reddit.com") }))
        assert(textImported.contains(where: { $0.domains.contains("9gag.com") }))
        assert(textImported.contains(where: { $0.domains.contains("chotot.com") }))
        
        // 9. Merging sites
        let existing = [
            BlockedSite(name: "Reddit", domains: ["reddit.com", "www.reddit.com"], isEnabled: true),
            BlockedSite(name: "Twitter", domains: ["twitter.com"], isEnabled: true)
        ]
        let toMerge = [
            BlockedSite(name: "Reddit", domains: ["old.reddit.com", "redd.it"], isEnabled: true), // overlap name & domain
            BlockedSite(name: "X", domains: ["x.com", "twitter.com"], isEnabled: true), // overlap domain
            BlockedSite(name: "New Site", domains: ["news.ycombinator.com"], isEnabled: true) // brand new
        ]
        let merged = BlockedSite.merge(existing: existing, imported: toMerge)
        assert(merged.count == 3, "Merged count should be 3 (Reddit, Twitter, New Site), got \(merged.count)")
        
        let mergedReddit = merged.first(where: { $0.name == "Reddit" })!
        assert(mergedReddit.domains.contains("old.reddit.com"), "Merged Reddit should have old.reddit.com")
        assert(mergedReddit.domains.contains("reddit.com"), "Merged Reddit should retain reddit.com")
        
        let mergedTwitter = merged.first(where: { $0.name == "Twitter" })!
        assert(mergedTwitter.domains.contains("x.com"), "Merged Twitter should have added x.com")
        assert(mergedTwitter.domains.contains("twitter.com"), "Merged Twitter should retain twitter.com")
        
        let mergedNewSite = merged.first(where: { $0.name == "New Site" })!
        assert(mergedNewSite.isCustom, "Newly added site in merge should be custom")
        assert(mergedNewSite.domains.contains("news.ycombinator.com"))
        
        // 10. Replacing sites
        let replaced = BlockedSite.replace(existing: existing, imported: toMerge)
        assert(replaced.count == 3, "Replaced count should equal imported count")
        assert(replaced.contains(where: { $0.name == "New Site" }))
        assert(!replaced.contains(where: { $0.name == "Twitter" }), "Replaced list should not contain original Twitter name")
        
        // 11. Error handling
        var emptyThrew = false
        do {
            _ = try BlockedSite.parseImport(data: Data())
        } catch BlockedSite.ImportError.emptyOrInvalidData {
            emptyThrew = true
        } catch {
            fatalError("Unexpected error thrown on empty data: \(error)")
        }
        assert(emptyThrew, "Must throw emptyOrInvalidData on empty input")
        
        var invalidThrew = false
        do {
            _ = try BlockedSite.parseImport(data: "# Only comments\n\n# Nothing else\n".data(using: .utf8)!)
        } catch BlockedSite.ImportError.noValidSitesFound {
            invalidThrew = true
        } catch {
            fatalError("Unexpected error thrown on comments-only input: \(error)")
        }
        assert(invalidThrew, "Must throw noValidSitesFound on comments-only input")
        
        print("✅ All tests passed successfully!")
    }
}
