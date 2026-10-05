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
        
        // 2. Hosts block generation
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
        
        print("✅ All tests passed successfully!")
    }
}
