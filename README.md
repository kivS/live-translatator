# RegionTranslate

A native macOS 14+ menu bar app that translates a selected screen region into English using your local llama.cpp server.

## Run

```sh
./script/build_and_run.sh
```

The app is built into `dist/RegionTranslate.app`. It intentionally runs without a Dock icon. Requires full Xcode; no third-party dependencies. `Package.swift` remains available for service unit tests; open the `.xcodeproj` to build and sign the app.

Open `RegionTranslate.xcodeproj`. Select the **RegionTranslate app target → Signing & Capabilities → All**, keep **Automatically manage signing** enabled, and choose your **Team**. Replace the revoked certificate through Xcode account settings. Select the **RegionTranslate** scheme and **My Mac**, then press **⌘R**.

`bin/dev` builds and launches Debug through Xcode. `bin/build` builds Release, replaces `/Applications/RegionTranslate.app`, and launches it, retaining the previous version in the printed backup folder. Both use the signing settings saved in the project without selecting or overriding your certificate. When migrating from an older signature, remove its Screen Recording entry and grant access to the newly installed app once.

1. Click the viewfinder menu bar icon or press **⌥⌘T**.
2. Allow Screen Recording access when prompted. Reopen the app if macOS requests it.
3. Drag with your mouse or trackpad to select a region. Drag inside to move it, or drag a corner to resize it.
4. Click **Translate**, press **Space**, or press **Return**. **Esc** cancels.
5. Read or copy the English translation in the movable floating result window.

Press **Esc** to dismiss the translation window. If translation is still running, dismissing the window cancels that request.

Right-click the menu bar icon for Settings and Quit. Settings also opens from the result window's gear button.

**Retry** resends the last captured region using the current settings, without taking another screenshot. Translation requests disable thinking mode and include fast, on-device macOS text recognition alongside the image to help the model read small text faithfully. Text recognition can still make mistakes; check important translations against the original.

## Model connection

Defaults to `http://localhost:8080/v1` and `unsloth/gemma-4-E4B-it-qat-GGUF:Q4_K_XL`. Both are editable in Settings. The app uses `/chat/completions` with a base64 PNG image. Your server needs image support and the **matching multimodal projector (mmproj)** loaded. A text-only model configuration cannot translate screenshots. See the [llama.cpp multimodal documentation](https://github.com/ggml-org/llama.cpp/blob/master/docs/multimodal.md).

Screens are frozen when selection starts. Each display supports its own selection; a region cannot span monitors. Only the confirmed crop is sent to the configured server. Captures remain in memory and are not saved to disk. Requests time out after five minutes and can be cancelled. Protected content may be unavailable to macOS screen capture.

## Development

### Llama app projector persistence

Llama regenerates `~/Library/Application Support/Llama/models.ini` when it scans installed models. Editing that generated file alone does not persist. Keep the matching `mmproj-F16.gguf` alongside the model in its Hugging Face cache snapshot so Llama discovers it and generates the `mmproj` setting automatically. The local installation has been configured this way using the same model revision and a SHA-256 verified projector. Llama's `serverPort` preference is set to `8080` to match this app's default endpoint.

`swift test` checks the multimodal request contract. The build script supports `--build`, `--verify`, `--debug`, `--logs`, and `--telemetry`. The Codex Run action uses the same script.

Manual verification: test permission denied/granted, mouse and trackpad selection, all four resize corners, movement at display edges, Return/Esc, secondary displays, full-screen apps, server unavailable, cancel during generation, and copying the result. Image translation requires a running vision-enabled server.
