import Foundation

// A host imports MarkdownViews alone and still sees the shared types (`TextChange`).
@_exported import MarkdownCore

/// The bundle that holds the shipped `Fonts` folder.
let resourceBundle = Bundle.module
