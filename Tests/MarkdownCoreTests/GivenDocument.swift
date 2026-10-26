import Foundation
import MarkdownCore

func givenDocument(
    _ text: String,
    features: MarkdownFeatures = MarkdownFeatures(),
    titleLine: MarkdownPresentation.TitleLine = .inBody
) -> MarkdownDocument {
    var presentation = MarkdownPresentation()
    presentation.titleLine = titleLine
    return MarkdownDocument(text: text, features: features, presentation: presentation)
}
