import Foundation
import MarkdownCore
import Testing

/// The Mac app's Info.plist (design log 001 › Files), read from the checkout.
struct AppInfoTests {
    static let plist = URL(filePath: #filePath)
        .deletingLastPathComponent().appending(path: "../../Apps/Mac/Info.plist").standardizedFileURL

    static func info() throws -> [String: Any] {
        let object = try PropertyListSerialization.propertyList(from: Data(contentsOf: plist), format: nil)
        return try #require(object as? [String: Any])
    }

    @Test
    func `the document type list equals the accepted extensions`() throws {
        let types = try #require(Self.info()["CFBundleDocumentTypes"] as? [[String: Any]])
        let listed = types.flatMap { $0["CFBundleTypeExtensions"] as? [String] ?? [] }

        #expect(listed.count == Set(listed).count)
        #expect(Set(listed) == DocumentFile.acceptedExtensions)
    }

    @Test
    func `the Markdown type declares every accepted extension but txt`() throws {
        let declared = try #require(Self.info()["UTImportedTypeDeclarations"] as? [[String: Any]])
        let markdown = try #require(declared
            .first { $0["UTTypeIdentifier"] as? String == "net.daringfireball.markdown" })
        let tags = try #require(markdown["UTTypeTagSpecification"] as? [String: [String]])

        #expect(Set(tags["public.filename-extension"] ?? []) == DocumentFile.acceptedExtensions.subtracting(["txt"]))
    }
}
