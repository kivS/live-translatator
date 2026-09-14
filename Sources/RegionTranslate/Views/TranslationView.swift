import SwiftUI

struct TranslationView: View {
    @ObservedObject var state: TranslationState
    let capture: () -> Void
    let cancel: () -> Void
    let retry: () -> Void
    let settings: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("English translation", systemImage: "character.bubble").font(.headline)
                Spacer()
                Button(action: settings) { Image(systemName: "gearshape") }.help("Settings")
            }
            if let preview = state.preview {
                Image(nsImage: preview).resizable().scaledToFit().frame(maxWidth: .infinity, maxHeight: 130)
                    .accessibilityLabel("Selected screen region")
            }
            if state.loading {
                HStack { ProgressView().controlSize(.small); Text("Translating with your local model…"); Spacer(); Button("Cancel", action: cancel) }
            }
            ScrollView {
                Text(state.error ?? state.text).textSelection(.enabled)
                    .foregroundStyle(state.error == nil ? Color.primary : Color.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }.frame(maxHeight: .infinity)
            Divider()
            HStack {
                Button("New Capture", action: capture)
                Button("Retry", action: retry)
                    .disabled(state.preview == nil || state.loading)
                    .help("Translate the same image again using current settings")
                Spacer()
                Button("Copy Translation") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(state.text, forType: .string)
                }.disabled(state.text.isEmpty || state.loading)
            }
        }.padding(20).frame(minWidth: 460, minHeight: 340)
    }
}
