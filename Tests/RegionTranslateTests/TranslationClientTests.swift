import XCTest
@testable import RegionTranslate

final class TranslationClientTests: XCTestCase {
    func testImageRequestUsesMultimodalContent() throws {
        let bytes = Data([0, 1, 2, 255])
        let request = try TranslationClient.request(image: bytes, endpoint: "http://localhost:8080/v1/", model: "test-model")
        XCTAssertEqual(request.url?.absoluteString, "http://localhost:8080/v1/chat/completions")
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as? [String: Any])
        XCTAssertEqual(json["model"] as? String, "test-model")
        XCTAssertEqual((json["chat_template_kwargs"] as? [String: Bool])?["enable_thinking"], false)
        let messages = try XCTUnwrap(json["messages"] as? [[String: Any]])
        let content = try XCTUnwrap(messages.first?["content"] as? [[String: Any]])
        let image = try XCTUnwrap(content.last?["image_url"] as? [String: String])
        XCTAssertEqual(image["url"], "data:image/png;base64," + bytes.base64EncodedString())
    }
    func testRejectsInvalidEndpoint() {
        XCTAssertThrowsError(try TranslationClient.request(image: Data(), endpoint: "file:///tmp/server", model: "test"))
    }

    func testReasoningOnlyAtLimitHasActionableError() {
        let data = Data(#"{"choices":[{"message":{"content":"","reasoning_content":"unfinished"},"finish_reason":"length"}]}"#.utf8)
        XCTAssertThrowsError(try TranslationClient.translation(from: data)) { error in
            XCTAssertTrue(error.localizedDescription.contains("output limit"))
        }
    }

    func testTranslationExcludesReasoning() throws {
        let data = Data(#"{"choices":[{"message":{"content":"Hello world","reasoning_content":"private reasoning"},"finish_reason":"stop"}]}"#.utf8)
        XCTAssertEqual(try TranslationClient.translation(from: data), "Hello world")
    }

    func testRecognizedTextAccompaniesImage() throws {
        let request = try TranslationClient.request(image: Data([1]), endpoint: "http://localhost:8080/v1", model: "test", recognizedText: "Bonjour")
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as? [String: Any])
        let messages = try XCTUnwrap(json["messages"] as? [[String: Any]])
        let content = try XCTUnwrap(messages.first?["content"] as? [[String: Any]])
        XCTAssertTrue((content.first?["text"] as? String)?.contains("<source_text>\nBonjour\n</source_text>") == true)
        XCTAssertEqual(content.last?["type"] as? String, "image_url")
    }
}
