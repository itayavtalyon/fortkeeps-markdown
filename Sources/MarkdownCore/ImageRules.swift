import Foundation

/// Where an image destination may load from (design log 001 › Images). The
/// app adds the I/O checks: a symlink that leaves the folder, a regular file,
/// folder access, the size and pixel limits, and each redirect hop's host.
public enum ImageSource: Equatable, Sendable {
    /// A file inside the document's folder.
    case local(URL)
    /// An https URL whose literal host is not on the blocklist.
    case remote(URL)
    case refused
}

public enum ImageRules {
    public static func classify(_ destination: String, documentURL: URL?) -> ImageSource {
        if let scheme = URLScheme.of(destination) {
            guard scheme == "https", let url = URL(string: destination), let host = url.host(), !isBlockedHost(host)
            else { return .refused }
            return .remote(url)
        }
        guard let file = FolderPath.resolve(destination, in: documentURL) else { return .refused }
        return .local(file)
    }

    /// True for a host the app must not contact: `localhost`, `.local`, a
    /// private, loopback, link-local, or multicast address, an IPv4 address
    /// written in any form other than dotted decimal, or a host with a percent
    /// escape (`%31%32%37.0.0.1` is 127.0.0.1 to a URL parser that decodes
    /// it), or a host with an empty label (`127.0.0.1..`, `example..com`).
    /// Trailing dots are the DNS root and do not change the host.
    /// The check reads the literal host only, before any DNS lookup.
    public static func isBlockedHost(_ host: String) -> Bool {
        guard !host.contains("%") else { return true }
        var name = host.lowercased()
        if name.hasPrefix("["), name.hasSuffix("]") {
            name = String(name.dropFirst().dropLast())
        }
        // One trailing dot is the DNS root (`localhost.`). Further dots are
        // empty labels (`127.0.0.1..`); strip every trailing dot, then refuse
        // a name that still has an empty label.
        while name.hasSuffix(".") {
            name.removeLast()
        }
        if name.isEmpty || name.contains("..") {
            return true
        }
        if name == "localhost" || name.hasSuffix(".local") {
            return true
        }
        if name.contains(":") {
            return IPAddress.isBlockedIPv6(name)
        }
        return IPAddress.isBlockedIPv4(name)
    }
}

/// The scheme of a destination, lowercased, or nil for a relative path.
enum URLScheme {
    static func of(_ destination: String) -> String? {
        guard let match = destination.prefixMatch(of: /([A-Za-z][A-Za-z0-9+.\-]*):/) else { return nil }
        return match.1.lowercased()
    }
}

/// A relative path resolved against a document's folder.
enum FolderPath {
    /// The file URL of a percent-decoded relative path, when it stays inside
    /// the document's folder; nil for an untitled document, an absolute path,
    /// a bad escape, or a path that leaves the folder.
    static func resolve(_ path: String, in documentURL: URL?) -> URL? {
        guard let documentURL, !path.isEmpty, !path.hasPrefix("/"), let decoded = path.removingPercentEncoding else {
            return nil
        }
        let folder = documentURL.deletingLastPathComponent().standardizedFileURL
        let file = URL(fileURLWithPath: decoded, relativeTo: folder).standardizedFileURL
        return file.path.hasPrefix(folder.path.hasSuffix("/") ? folder.path : folder.path + "/") ? file : nil
    }
}
