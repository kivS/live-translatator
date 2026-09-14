import Foundation
import Vision

enum ScreenTextRecognizer {
    static func text(in image: Data) throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .fast
        request.automaticallyDetectsLanguage = true
        try VNImageRequestHandler(data: image, options: [:]).perform([request])
        return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
    }
}
