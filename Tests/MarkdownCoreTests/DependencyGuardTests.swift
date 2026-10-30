import Foundation
import Testing

/// Design › Product: the Acknowledgements list names every resolved package,
/// and no package on the analytics denylist is resolved or linked.
struct DependencyGuardTests {
    static let sentryResolved = """
    {
      "pins" : [
        {
          "identity" : "sentry-cocoa",
          "kind" : "remoteSourceControl",
          "location" : "https://github.com/getsentry/sentry-cocoa.git",
          "state" : {
            "revision" : "0ffc3c6287461962cb2a81e57fc0ee0335d8d56a",
            "version" : "8.40.1"
          }
        }
      ],
      "version" : 2
    }
    """

    static let markdownResolved = """
    {
      "pins" : [
        {
          "identity" : "swift-cmark",
          "kind" : "remoteSourceControl",
          "location" : "https://github.com/swiftlang/swift-cmark.git",
          "state" : {
            "revision" : "b022b08312decdc46585e0b3440d97f6f22ef703",
            "version" : "0.6.0"
          }
        },
        {
          "identity" : "swift-markdown",
          "kind" : "remoteSourceControl",
          "location" : "https://github.com/swiftlang/swift-markdown.git",
          "state" : {
            "revision" : "25cb61d3482054b09ae76ca4f281b1bfe7fe5a43",
            "version" : "0.9.0"
          }
        }
      ],
      "version" : 2
    }
    """

    static func givenAcknowledgements(packages: [String?]) throws -> Data {
        let entries = packages.map { package in
            DependencyGuard.Acknowledgement(
                name: package ?? "IBM Plex",
                package: package,
                license: "MIT",
                file: "x.txt"
            )
        }
        return try JSONEncoder().encode(entries)
    }

    // MARK: acknowledgements check

    @Test
    func `acknowledgements check fails when a resolved package is missing from the list`() throws {
        let missing = try DependencyGuard.missingAcknowledgements(
            resolved: Data(Self.markdownResolved.utf8),
            acknowledgements: Self.givenAcknowledgements(packages: [nil, "swift-markdown"])
        )

        #expect(missing == ["swift-cmark"])
    }

    @Test
    func `acknowledgements check passes when every resolved package is listed`() throws {
        let missing = try DependencyGuard.missingAcknowledgements(
            resolved: Data(Self.markdownResolved.utf8),
            acknowledgements: Self.givenAcknowledgements(packages: [nil, "swift-markdown", "swift-cmark"])
        )

        #expect(missing.isEmpty)
    }

    @Test
    func `acknowledgements check rejects a Package.resolved with no pins array`() {
        #expect(throws: DecodingError.self) {
            try DependencyGuard.missingAcknowledgements(
                resolved: Data(#"{"object": {"pins": []}, "version": 1}"#.utf8),
                acknowledgements: Self.givenAcknowledgements(packages: [nil])
            )
        }
    }

    @Test
    func `repo Acknowledgements list names every package in Package.resolved`() throws {
        let acknowledgements = try Data(contentsOf: RepoPath.url("Acknowledgements/acknowledgements.json"))
        let resolvedURL = RepoPath.url("Package.resolved")
        guard FileManager.default.fileExists(atPath: resolvedURL.path) else {
            let manifest = try String(contentsOf: RepoPath.url("Package.swift"), encoding: .utf8)
            #expect(
                !manifest.contains(".package("),
                "Package.swift declares a dependency but Package.resolved is missing"
            )
            return
        }
        let resolved = try Data(contentsOf: resolvedURL)

        #expect(try DependencyGuard.missingAcknowledgements(resolved: resolved, acknowledgements: acknowledgements)
            .isEmpty)
    }

    @Test
    func `repo Acknowledgements entries each have a name, a license, and a non-empty license file`() throws {
        let entries = try JSONDecoder().decode(
            [DependencyGuard.Acknowledgement].self,
            from: Data(contentsOf: RepoPath.url("Acknowledgements/acknowledgements.json"))
        )
        try #require(!entries.isEmpty)

        for entry in entries {
            let text = try String(contentsOf: RepoPath.url("Acknowledgements/\(entry.file)"), encoding: .utf8)
            #expect(!entry.name.isEmpty && !entry.license.isEmpty, "\(entry)")
            #expect(!text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "\(entry.file) is empty")
        }
    }

    // MARK: denylist check

    @Test
    func `denylist check fails on a Package.resolved that contains Sentry`() {
        #expect(DependencyGuard.denylistHits(in: Self.sentryResolved) == ["Sentry"])
    }

    @Test(arguments: [
        ("https://github.com/firebase/firebase-ios-sdk.git", "Firebase"),
        ("https://github.com/amplitude/Amplitude-Swift.git", "Amplitude"),
        ("https://github.com/mixpanel/mixpanel-swift.git", "Mixpanel"),
        ("https://github.com/segmentio/analytics-swift.git", "Segment"),
        ("https://github.com/microsoft/appcenter-sdk-apple.git", "AppCenter"),
        ("https://github.com/bugsnag/bugsnag-cocoa.git", "Bugsnag")
    ])
    func `denylist check finds each listed vendor in a dependency URL`(url: String, vendor: String) {
        let manifestLine = #".package(url: "\#(url)", from: "1.0.0")"#

        #expect(DependencyGuard.denylistHits(in: manifestLine) == [vendor])
    }

    @Test
    func `denylist check finds Crashlytics in a linked product`() {
        let product = #".product(name: "FirebaseCrashlytics", package: "firebase-ios-sdk")"#

        #expect(DependencyGuard.denylistHits(in: product) == ["Firebase", "Crashlytics"])
    }

    @Test
    func `denylist check passes on the swift-markdown packages`() {
        #expect(DependencyGuard.denylistHits(in: Self.markdownResolved).isEmpty)
    }

    @Test(arguments: ["Package.swift", "Package.resolved"])
    func `repo manifest files link no denylisted package`(file: String) throws {
        let url = RepoPath.url(file)
        guard FileManager.default.fileExists(atPath: url.path) else {
            #expect(file == "Package.resolved", "\(file) is missing")
            return
        }
        let text = try String(contentsOf: url, encoding: .utf8)

        #expect(DependencyGuard.denylistHits(in: text).isEmpty)
    }
}

enum DependencyGuard {
    static let denylist = [
        "Firebase",
        "Sentry",
        "Amplitude",
        "Mixpanel",
        "Segment",
        "AppCenter",
        "Bugsnag",
        "Crashlytics"
    ]

    struct Acknowledgement: Codable {
        let name: String
        let package: String?
        let license: String
        let file: String
    }

    private struct Resolved: Decodable {
        let pins: [ResolvedPin]
    }

    private struct ResolvedPin: Decodable {
        let identity: String
    }

    /// Resolved package identities with no Acknowledgements entry, sorted.
    static func missingAcknowledgements(resolved: Data, acknowledgements: Data) throws -> [String] {
        let pins = try JSONDecoder().decode(Resolved.self, from: resolved).pins.map(\.identity)
        let listed = try Set(JSONDecoder().decode([Acknowledgement].self, from: acknowledgements).compactMap(\.package))
        return pins.filter { !listed.contains($0) }.sorted()
    }

    /// Denylist names found anywhere in the text, case-insensitive.
    static func denylistHits(in text: String) -> [String] {
        denylist.filter { text.localizedCaseInsensitiveContains($0) }
    }
}
