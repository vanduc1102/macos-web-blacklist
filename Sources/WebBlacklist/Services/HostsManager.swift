import Foundation

public final class HostsManager {
    public static let shared = HostsManager()
    
    public let hostsPath = "/etc/hosts"
    public let beginMarker = "# === BEGIN WEB-BLACKLIST MANAGED BLOCK ==="
    public let endMarker = "# === END WEB-BLACKLIST MANAGED BLOCK ==="
    
    private init() {}
    
    /// Checks if `/etc/hosts` is directly writable by the current user without root elevation
    public var isHostsWritable: Bool {
        let fd = open(hostsPath, O_WRONLY | O_APPEND)
        if fd >= 0 {
            close(fd)
            return true
        }
        return false
    }
    
    /// Reads the current `/etc/hosts` content
    public func readHosts() throws -> String {
        return try String(contentsOfFile: hostsPath, encoding: .utf8)
    }
    
    /// Determines whether the Web-Blacklist block is currently active in `/etc/hosts`
    public func isBlacklistActive() -> Bool {
        guard let content = try? readHosts() else { return false }
        return content.contains(beginMarker) && content.contains(endMarker)
    }
    
    /// Generates the hosts block content for enabled sites
    public func generateBlockContent(for sites: [BlockedSite]) -> String {
        let enabledSites = sites.filter { $0.isEnabled }
        var allDomains: Set<String> = []
        for site in enabledSites {
            for domain in site.domains {
                let trimmed = domain.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if !trimmed.isEmpty {
                    allDomains.insert(trimmed)
                }
            }
        }
        
        let sortedDomains = Array(allDomains).sorted()
        
        var lines: [String] = []
        lines.append(beginMarker)
        lines.append("# DO NOT EDIT MANUALLY - MANAGED BY WEB-BLACKLIST APP")
        lines.append("# Total blocked domains: \(sortedDomains.count)")
        lines.append("# Applied on: \(Date().description)")
        
        // IPv4 null route
        for domain in sortedDomains {
            lines.append("0.0.0.0 \(domain)")
        }
        
        // IPv6 null route
        for domain in sortedDomains {
            lines.append("::1 \(domain)")
        }
        
        lines.append(endMarker)
        return lines.joined(separator: "\n")
    }
    
    /// Strips all Web-Blacklist blocks from existing hosts content
    public func stripManagedBlock(from content: String) -> String {
        var modified = content
        while let startIndex = modified.range(of: beginMarker)?.lowerBound,
              let endIndex = modified.range(of: endMarker)?.upperBound {
            modified.removeSubrange(startIndex..<endIndex)
        }
        return modified.trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
    }
    
    /// Applies the blacklist to `/etc/hosts`
    public func applyBlacklist(sites: [BlockedSite]) throws {
        let currentContent = try readHosts()
        let cleanContent = stripManagedBlock(from: currentContent)
        let blockContent = generateBlockContent(for: sites)
        
        let newContent = cleanContent + "\n\n" + blockContent + "\n"
        try writeHosts(content: newContent)
        flushDNS()
    }
    
    /// Removes the blacklist from `/etc/hosts`
    public func removeBlacklist() throws {
        let currentContent = try readHosts()
        let cleanContent = stripManagedBlock(from: currentContent)
        try writeHosts(content: cleanContent)
        flushDNS()
    }
    
    /// Writes the content to `/etc/hosts`, first trying direct POSIX write, then falling back to AppleScript
    private func writeHosts(content: String) throws {
        do {
            try writeDirectly(content: content)
        } catch {
            // Fallback to administrator privileges if direct write fails
            try writeWithPrivileges(content: content)
        }
    }
    
    /// Direct POSIX truncate-and-write to avoid temp file creation in /etc (which causes CocoaError 513)
    private func writeDirectly(content: String) throws {
        guard let data = content.data(using: .utf8) else {
            throw NSError(domain: "HostsManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode string as UTF-8"])
        }
        
        let fd = open(hostsPath, O_WRONLY | O_TRUNC)
        guard fd >= 0 else {
            let errStr = String(cString: strerror(errno))
            throw NSError(domain: "HostsManager", code: Int(errno), userInfo: [NSLocalizedDescriptionKey: "Cannot open \(hostsPath) for writing: \(errStr)"])
        }
        defer { close(fd) }
        
        try data.withUnsafeBytes { rawBuffer in
            guard let ptr = rawBuffer.baseAddress else { return }
            var totalWritten = 0
            while totalWritten < data.count {
                let written = write(fd, ptr.advanced(by: totalWritten), data.count - totalWritten)
                if written < 0 {
                    let errStr = String(cString: strerror(errno))
                    throw NSError(domain: "HostsManager", code: Int(errno), userInfo: [NSLocalizedDescriptionKey: "Failed writing to \(hostsPath): \(errStr)"])
                }
                totalWritten += written
            }
        }
        fsync(fd)
    }
    
    /// Fallback write using AppleScript administrator prompt
    private func writeWithPrivileges(content: String) throws {
        let tempFile = "/tmp/web_blacklist_\(UUID().uuidString).tmp"
        try content.write(toFile: tempFile, atomically: false, encoding: .utf8)
        defer {
            try? FileManager.default.removeItem(atPath: tempFile)
        }
        
        let script = "do shell script \"cp '\(tempFile)' '\(hostsPath)' && chmod 664 '\(hostsPath)' && chgrp admin '\(hostsPath)' && dscacheutil -flushcache\" with administrator privileges"
        var errorInfo: NSDictionary?
        let appleScript = NSAppleScript(source: script)
        appleScript?.executeAndReturnError(&errorInfo)
        
        if let error = errorInfo {
            let msg = error[NSAppleScript.errorMessage] as? String ?? "Failed to write /etc/hosts with administrator privileges"
            throw NSError(domain: "HostsManager", code: 1, userInfo: [NSLocalizedDescriptionKey: msg])
        }
    }
    
    /// One-time setup to grant the admin group write permissions to `/etc/hosts`
    public func grantDirectWritePermissions(completion: @escaping (Result<Void, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let script = "do shell script \"chmod 664 /etc/hosts && chgrp admin /etc/hosts\" with administrator privileges"
            var errorInfo: NSDictionary?
            let appleScript = NSAppleScript(source: script)
            appleScript?.executeAndReturnError(&errorInfo)
            
            DispatchQueue.main.async {
                if let error = errorInfo {
                    let msg = error[NSAppleScript.errorMessage] as? String ?? "Authorization failed"
                    completion(.failure(NSError(domain: "HostsManager", code: 2, userInfo: [NSLocalizedDescriptionKey: msg])))
                } else {
                    completion(.success(()))
                }
            }
        }
    }
    
    /// Flushes macOS DNS cache
    public func flushDNS() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/dscacheutil")
        process.arguments = ["-flushcache"]
        try? process.run()
        process.waitUntilExit()
    }
}
