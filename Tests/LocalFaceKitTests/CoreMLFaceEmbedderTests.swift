import Foundation
import XCTest

@testable import LocalFaceKit

final class CoreMLFaceEmbedderTests: XCTestCase {
  func testEmbedderRejectsNonLocalModelURL() {
    let remoteURL = URL(string: "https://example.invalid/model.mlmodelc")!

    XCTAssertThrowsError(
      try CoreMLFaceEmbedder(
        modelURL: remoteURL,
        modelIdentifier: "test-v1"
      )
    ) { error in
      XCTAssertEqual(error as? CoreMLFaceEmbedderError, .modelMustBeLocal)
    }
  }
}
