import SwiftUI

struct SettingsView: View {
    @AppStorage("endpoint") private var endpoint = "http://localhost:8080/v1"
    @AppStorage("model") private var model = TranslationClient.defaultModel
    var body: some View {
        Form {
            Text("RegionTranslate").font(.title2.bold())
            TextField("Server API URL", text: $endpoint)
            TextField("Model", text: $model)
            Text("Use an API base URL ending in /v1. Images are sent to this address only after you confirm a selection.")
                .font(.caption).foregroundStyle(.secondary)
            Divider()
            Text("Capture: ⌘⇧T or click the menu bar icon")
            Text("Drag to select. Drag inside to move. Drag a corner to resize. Space, Return, or Translate confirms; Esc cancels.")
            Text("Your llama server must load the matching vision projector (mmproj) to read screenshots.")
                .font(.caption).foregroundStyle(.secondary)
            Button("Screen Recording Settings") {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
            }
        }.padding(24).frame(width: 540)
    }
}
