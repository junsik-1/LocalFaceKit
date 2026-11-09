import CoreGraphics
import XCTest

@testable import LocalFaceKit

final class FivePointFaceAlignerTests: XCTestCase {
  func testExtractsImageSpaceAnchorsAndOrdersThemByPosition() throws {
    let face = DetectedFace(
      boundingBox: CGRect(x: 0.2, y: 0.1, width: 0.6, height: 0.8),
      confidence: 0.99,
      landmarks: FaceLandmarks(
        leftEye: [NormalizedFacePoint(x: 0.75, y: 0.75)],
        rightEye: [NormalizedFacePoint(x: 0.25, y: 0.75)],
        nose: [NormalizedFacePoint(x: 0.5, y: 0.5)],
        outerLips: [
          NormalizedFacePoint(x: 0.65, y: 0.25),
          NormalizedFacePoint(x: 0.35, y: 0.25),
        ]
      )
    )

    let anchors = try FivePointFaceAligner.landmarks(for: face)

    XCTAssertEqual(anchors.leftEye.x, 0.35, accuracy: 0.0001)
    XCTAssertEqual(anchors.leftEye.y, 0.7, accuracy: 0.0001)
    XCTAssertEqual(anchors.rightEye.x, 0.65, accuracy: 0.0001)
    XCTAssertEqual(anchors.nose.x, 0.5, accuracy: 0.0001)
    XCTAssertEqual(anchors.leftMouth.y, 0.3, accuracy: 0.0001)
  }

  func testRejectsIncompleteLandmarks() {
    let face = DetectedFace(
      boundingBox: CGRect(x: 0.2, y: 0.2, width: 0.6, height: 0.6),
      confidence: 0.99,
      landmarks: FaceLandmarks()
    )

    XCTAssertThrowsError(try FivePointFaceAligner.landmarks(for: face)) { error in
      XCTAssertEqual(error as? FivePointFaceAlignerError, .missingLandmarks)
    }
  }

  func testSimilarityTransformMapsScaleRotationAndTranslation() throws {
    let source = [
      CGPoint(x: 0, y: 0),
      CGPoint(x: 2, y: 0),
      CGPoint(x: 1, y: 2),
    ]
    let expected = CGAffineTransform(a: 0, b: 3, c: -3, d: 0, tx: 10, ty: 20)
    let target = source.map { $0.applying(expected) }

    let transform = try FivePointFaceAligner.similarityTransform(
      from: source,
      to: target
    )

    for (point, expectedPoint) in zip(source, target) {
      let actual = point.applying(transform)
      XCTAssertEqual(actual.x, expectedPoint.x, accuracy: 0.0001)
      XCTAssertEqual(actual.y, expectedPoint.y, accuracy: 0.0001)
    }
  }

  func testRejectsInvalidOutputSize() {
    XCTAssertThrowsError(try FivePointFaceAligner(outputSize: 0)) { error in
      XCTAssertEqual(error as? FivePointFaceAlignerError, .invalidOutputSize)
    }
  }
}
