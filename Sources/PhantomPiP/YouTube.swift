import Foundation

enum YouTube {
    /// Extracts a video ID from the URL shapes we support: `watch?v=`,
    /// `youtu.be/`, `shorts/`, `embed/`, `live/`. Accepts input without a
    /// scheme. Returns nil for non-YouTube URLs or implausible IDs.
    static func id(from raw: String) -> String? {
        let normalized = raw.contains("://") ? raw : "https://\(raw)"
        guard let comps = URLComponents(string: normalized),
              let host = comps.host?.lowercased() else { return nil }

        var id: String?
        if host.contains("youtu.be") {
            id = comps.path.split(separator: "/").first.map(String.init)
        } else if host.contains("youtube.com") {
            let parts = comps.path.split(separator: "/").map(String.init)
            if comps.path.hasPrefix("/watch") {
                id = comps.queryItems?.first(where: { $0.name == "v" })?.value
            } else if let kind = parts.first,
                      kind == "shorts" || kind == "embed" || kind == "live",
                      parts.count > 1 {
                id = parts[1]
            }
        }
        guard let videoID = id,
              !videoID.isEmpty,
              videoID.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" })
        else { return nil }
        return videoID
    }
}
