import XCTest

@testable import LocalFaceKit

final class FaceEnrollmentSessionTests: XCTestCase {
  func testCollectsSpacedSamplesAndCapsCollection() throws {
    var session = try FaceEnrollmentSession(
      modelIdentifier: "test-v1", requiredSampleCount: 2, minimumSampleInterval: 0.5
    )
    let embedding = try FaceEmbedding([1, 0])
    XCTAssertTrue(try session.append(embedding, modelIdentifier: "test-v1", timestamp: 0))
    XCTAssertFalse(try session.append(embedding, modelIdentifier: "test-v1", timestamp: 0.25))
    XCTAssertEqual(session.progress, 0.5)
    XCTAssertThrowsError(try session.template(subjectID: "alice"))
    XCTAssertTrue(try session.append(embedding, modelIdentifier: "test-v1", timestamp: 0.5))
    XCTAssertTrue(session.isComplete)
    XCTAssertEqual(session.progress, 1)
    XCTAssertFalse(try session.append(embedding, modelIdentifier: "test-v1", timestamp: 1))
    XCTAssertEqual(try session.template(subjectID: "alice").embeddings.count, 2)
  }

  func testInvalidSamplesDoNotAdvanceProgress() throws {
    var session = try FaceEnrollmentSession(modelIdentifier: "test-v1")
    let embedding = try FaceEmbedding([1, 0])
    try session.append(embedding, modelIdentifier: "test-v1", timestamp: 1)
    XCTAssertThrowsError(try session.append(embedding, modelIdentifier: "other", timestamp: 2))
    XCTAssertThrowsError(try session.append(FaceEmbedding([1, 0, 0]), modelIdentifier: "test-v1", timestamp: 2))
    for timestamp in [Double.nan, Double.infinity, -1, 0] {
      XCTAssertThrowsError(try session.append(embedding, modelIdentifier: "test-v1", timestamp: timestamp))
    }
    XCTAssertEqual(session.embeddings.count, 1)
  }

  func testResetAllowsNewCameraTimeline() throws {
    var session = try FaceEnrollmentSession(modelIdentifier: "test-v1")
    let embedding = try FaceEmbedding([1, 0])
    try session.append(embedding, modelIdentifier: "test-v1", timestamp: 100)
    session.reset()
    XCTAssertEqual(session.progress, 0)
    XCTAssertFalse(session.isComplete)
    XCTAssertTrue(try session.append(embedding, modelIdentifier: "test-v1", timestamp: 0))
  }

  func testRejectsInvalidConfiguration() {
    XCTAssertThrowsError(try FaceEnrollmentSession(modelIdentifier: " "))
    for count in [0, 1, 31] {
      XCTAssertThrowsError(try FaceEnrollmentSession(modelIdentifier: "v1", requiredSampleCount: count))
    }
    for interval in [0, -1, Double.nan, Double.infinity] {
      XCTAssertThrowsError(try FaceEnrollmentSession(modelIdentifier: "v1", minimumSampleInterval: interval))
    }
  }

  func testCompletedSamplesCanBeEnrolledAndVerified() async throws {
    let store = InMemoryTemplateStore()
    let service = FaceRecognitionService(
      modelIdentifier: "test-v1", store: store,
      matchingPolicy: try MatchingPolicy(threshold: 0.75)
    )
    var session = try FaceEnrollmentSession(modelIdentifier: "test-v1", requiredSampleCount: 2)
    try session.append(FaceEmbedding([1, 0]), modelIdentifier: "test-v1", timestamp: 0)
    try session.append(FaceEmbedding([0.98, 0.02]), modelIdentifier: "test-v1", timestamp: 1)
    let template = try session.template(subjectID: "alice")
    try await service.enroll(subjectID: template.subjectID, embeddings: template.embeddings)
    let result = try await service.verify(FaceEmbedding([1, 0]), claimedSubjectID: "alice")
    XCTAssertEqual(result.decision, .match)
    session.reset()
    try await service.remove(subjectID: "alice")
    let remaining = try await store.allTemplates()
    XCTAssertTrue(remaining.isEmpty)
  }
}
