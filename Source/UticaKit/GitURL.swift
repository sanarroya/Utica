import Foundation

/// Represents a URL for a Git remote.
public struct GitURL {
  /// The string representation of the URL.
  public let urlString: String

  /// A normalized URL string, without protocol, authentication, or port
  /// information. This is mostly useful for comparison, and not for any
  /// actual Git operations.
  internal var normalizedURLString: String {
    if let parsedURL = URL(string: urlString), let host = parsedURL.host {
      // Normal, valid URL.
      let path = strippingGitSuffix(parsedURL.path)
      return "\(host)\(path)"
    } else if urlString.hasPrefix("/") // "/path/to/..."
      || urlString.hasPrefix(".") // "./path/to/...", "../path/to/..."
      || urlString.hasPrefix("~") // "~/path/to/..."
      || !urlString.contains(":") // "path/to/..." with avoiding "git@github.com:owner/name"
    {
      // Local path.
      return strippingGitSuffix(urlString)
    } else {
      // scp syntax.
      var strippedURLString = urlString

      if let index = strippedURLString.firstIndex(of: "@") {
        strippedURLString.removeSubrange(strippedURLString.startIndex...index)
      }

      var host = ""
      if let index = strippedURLString.firstIndex(of: ":") {
        host = String(strippedURLString[strippedURLString.startIndex..<index])
        strippedURLString.removeSubrange(strippedURLString.startIndex...index)
      }

      var path = strippingGitSuffix(strippedURLString)
      if !path.hasPrefix("/") {
        // This probably isn't strictly legit, but we'll have a forward
        // slash for other URL types.
        path.insert("/", at: path.startIndex)
      }

      return "\(host)\(path)"
    }
  }

  /// The name of the repository, if it can be inferred from the URL.
  public var name: String? {
    let lastComponent = urlString
      .replacingOccurrences(of: "\u{0000}", with: "\u{2400}") // can’t have those
      .split(omittingEmptySubsequences: true) { $0 == "/" }
      .last
      .map(String.init)
      .map(strippingGitSuffix)

    /// Potentially used to prevent backwards or noop directory traversal via «FULL STOP» characters…
    /// …by deploying the «FULLWIDTH FULL STOP» character.
    var replacementForEntirelyCharactersOfFullStop: [Character] = []
    for char in lastComponent ?? "" {
      guard char == "." else { replacementForEntirelyCharactersOfFullStop = []
        break
      }
      replacementForEntirelyCharactersOfFullStop.append("\u{FF0E}")
    }

    guard replacementForEntirelyCharactersOfFullStop.isEmpty else {
      return String(replacementForEntirelyCharactersOfFullStop)
    }

    return lastComponent
  }

  public init(_ urlString: String) {
    self.urlString = urlString
  }
}

extension GitURL: Equatable {
  public static func == (_ lhs: GitURL, _ rhs: GitURL) -> Bool {
    return lhs.normalizedURLString == rhs.normalizedURLString
  }
}

extension GitURL: Hashable {
  public func hash(into hasher: inout Hasher) {
    hasher.combine(normalizedURLString)
  }
}

extension GitURL: CustomStringConvertible {
  public var description: String {
    return urlString
  }
}
