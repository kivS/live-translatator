import SwiftUI

@MainActor
final class TranslationState: ObservableObject {
    @Published var text = ""
    @Published var error: String?
    @Published var loading = false
    @Published var preview: NSImage?
}
