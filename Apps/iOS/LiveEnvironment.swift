import UIKit
import UniformTypeIdentifiers

/// The system services of the app; the tests use their own.
extension ScrollEnvironment {
    static let live = ScrollEnvironment(
        transport: URLSessionTransport(),
        access: FolderBookmarks.standard,
        openURL: { UIApplication.shared.open($0) },
        openFile: { SceneDelegate.current?.open([$0]) },
        closeFile: { SceneDelegate.current?.close($0) },
        present: { controller, over in over.present(controller, animated: true) },
        appFolder: .documentsDirectory
    )
}

extension FolderBookmarks {
    /// The Files folder picker, opened at the document's folder.
    static let standard = FolderBookmarks(defaults: .standard) { folder in
        guard let over = SceneDelegate.current?.window?.rootViewController else { return nil }
        let top = sequence(first: over, next: \.presentedViewController).reduce(over) { $1 }
        return await withCheckedContinuation { done in
            let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
            picker.directoryURL = folder
            let delegate = FolderPickerDelegate { done.resume(returning: $0) }
            picker.delegate = delegate
            objc_setAssociatedObject(picker, &FolderPickerDelegate.key, delegate, .OBJC_ASSOCIATION_RETAIN)
            top.present(picker, animated: true)
        }
    }
}

/// Answers the folder picker once.
private final class FolderPickerDelegate: NSObject, UIDocumentPickerDelegate {
    nonisolated(unsafe) static var key = 0
    private var finish: ((URL?) -> Void)?

    init(finish: @escaping (URL?) -> Void) {
        self.finish = finish
    }

    func documentPicker(_: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        finish?(urls.first)
        finish = nil
    }

    func documentPickerWasCancelled(_: UIDocumentPickerViewController) {
        finish?(nil)
        finish = nil
    }
}
