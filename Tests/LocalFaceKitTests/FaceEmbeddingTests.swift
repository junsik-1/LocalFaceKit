import XCTest

@testable import LocalFaceKit

final class FaceEmbeddingTests: XCTestCase {
  func testEmbeddingIsNormalized() throws {
    let embedding = try FaceEmbedding([3, 4])

    XCTAssertEqual(embedding.values[0], 0.6, accuracy: 0.0001)
    XCTAssertEqual(embedding.values[1], 0.8, accuracy: 0.0001)
  }

  func testEmbeddingRejectsInvalidInput() {
    XCTAssertThrowsError(try FaceEmbedding([])) { error in
      XCTAssertEqual(error as? FaceEmbeddingError, .empty)
    }
    XCTAssertThrowsError(try FaceEmbedding([0, 0])) { error in
      XCTAssertEqual(error as? FaceEmbeddingError, .zeroNorm)
    }
  }

  func testCosineSimilarityRequiresMatchingDimensions() throws {
    let first = try FaceEmbedding([1, 0])
    let second = try FaceEmbedding([1, 0, 0])

    XCTAssertThrowsError(try first.cosineSimilarity(to: second)) { error in
      XCTAssertEqual(
        error as? FaceEmbeddingError,
        .dimensionMismatch(expected: 2, actual: 3)
      )
    }
  }
}
