import Foundation

/// Parses the `phantompip://` deep-link the Chrome extension fires.
///
/// Accepted shapes (all yield the same target):
///   phantompip://play?u=<percent-encoded https URL>
///   phantompip://play?url=<percent-encoded https URL>
///   phantompip://play/<percent-encoded https URL>
///   phantompip://<percent-encoded https URL>
///
/// Only http/https targets are returned — an external entry point shouldn't
/// be able to make the app open arbitrary schemes.
enum PhantomURL {
    static let scheme = "phantompip"

    static func videoTarget(from url: URL) -> String? {
        guard url.scheme?.lowercased() == scheme else { return nil }

        let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)

        // Preferred: explicit query parameter (URLComponents percent-decodes).
        if let q = comps?.queryItems?.first(where: { $0.name == "u" || $0.name == "url" })?
            .value, let target = sanitize(q) {
            return target
        }

        // Fallback: the URL itself, minus scheme and an optional "play/".
        var rest = url.absoluteString
        if let r = rest.range(of: "://") { rest.removeSubrange(rest.startIndex..<r.upperBound) }
        if let qm = rest.firstIndex(of: "?") { rest = String(rest[..<qm]) }
        for prefix in ["play/", "play"] where rest.hasPrefix(prefix) {
            rest.removeFirst(prefix.count)
        }
        let decoded = rest.removingPercentEncoding ?? rest
        return sanitize(decoded)
    }

    private static func sanitize(_ s: String) -> String? {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = t.lowercased()
        guard lower.hasPrefix("https://") || lower.hasPrefix("http://") else { return nil }
        return t
    }
}
