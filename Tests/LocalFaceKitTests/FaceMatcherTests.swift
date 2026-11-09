import XCTest

@testable import LocalFaceKit

final class FaceMatcherTests: XCTestCase {
  func testVerifiesMatchingTemplate() throws {
    let template = try FaceTemplate(
      subjectID: "alice",
      modelIdentifier: "test-v1",
      embeddings: [
        try FaceEmbedding([1, 0]),
        try FaceEmbedding([0.99, 0.01]),
      ]
    )
    let policy = try MatchingPolicy(threshold: 0.8)
    let matcher = CosineFaceMatcher(policy: policy)

    let result = try matcher.verify(
      FaceEmbedding([1, 0]),
      against: template,
      modelIdentifier: "test-v1"
    )

    XCTAssertEqual(result.decision, .match)
    XCTAssertEqual(result.subjectID, "alice")
  }

  func testRejectsAmbiguousIdentification() throws {
    let templates = try [
      FaceTemplate(
        subjectID: "alice",
        modelIdentifier: "test-v1",
        embeddings: [FaceEmbedding([1, 0])]
      ),
      FaceTemplate(
        subjectID: "bob",
        modelIdentifier: "test-v1",
        embeddings: [FaceEmbedding([0.999, 0.001])]
      ),
    ]
    let policy = try MatchingPolicy(threshold: 0.8, minimumMargin: 0.05)
    let matcher = CosineFaceMatcher(policy: policy)

    let result = try matcher.identify(
      FaceEmbedding([1, 0]),
      among: templates,
      modelIdentifier: "test-v1"
    )

    XCTAssertEqual(result.decision, .ambiguous)
    XCTAssertNil(result.subjectID)
  }
}
