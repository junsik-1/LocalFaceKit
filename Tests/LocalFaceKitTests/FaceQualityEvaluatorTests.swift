import CoreGraphics
import CoreVideo
import XCTest

@testable import LocalFaceKit

final class FaceQualityEvaluatorTests: XCTestCase {
  func testAcceptsOneCenteredFrontalFace() {
    let result = FaceQualityEvaluator().evaluate([makeFace()])

    XCTAssertTrue(result.isAccepted)
    XCTAssertEqual(result.metrics.faceArea ?? 0, 0.36, accuracy: 0.0001)
    XCTAssertNil(result.metrics.meanLuminance)
  }

  func testRequiresExactlyOneFace() {
    let evaluator = FaceQualityEvaluator()

    XCTAssertEqual(evaluator.evaluate([]).issues, [.noFace])
    XCTAssertEqual(
      evaluator.evaluate([makeFace(), makeFace()]).issues,
      [.multipleFaces(count: 2)]
    )
  }

  func testReportsSizeClippingPoseAndMissingLandmarks() throws {
    let policy = try FaceQualityPolicy(
      minimumConfidence: 0.9,
      minimumFaceArea: 0.2,
      edgeMargin: 0.02,
      maximumYaw: 0.2,
      maximumRoll: 0.2,
      maximumPitch: 0.2
    )
    let face = DetectedFace(
      boundingBox: CGRect(x: 0, y: 0.4, width: 0.2, height: 0.2),
      confidence: 0.5,
      roll: -0.4,
      yaw: 0.4,
      pitch: 0.4
    )

    let result = FaceQualityEvaluator(policy: policy).evaluate([face])

    XCTAssertFalse(result.isAccepted)
    XCTAssertTrue(result.issues.contains(.faceClipped))
    XCTAssertTrue(result.issues.contains(.missingLandmarks))
    XCTAssertTrue(
      result.issues.contains { issue in
        if case .lowConfidence = issue { return true }
        return false
      })
    XCTAssertTrue(
      result.issues.contains { issue in
        if case .faceTooSmall = issue { return true }
        return false
      })
    XCTAssertTrue(
      result.issues.contains { issue in
        if case .excessiveYaw = issue { return true }
        return false
      })
    XCTAssertTrue(
      result.issues.contains { issue in
        if case .excessiveRoll = issue { return true }
        return false
      })
    XCTAssertTrue(
      result.issues.contains { issue in
        if case .excessivePitch = issue { return true }
        return false
      })
  }

  func testUniformFrameIsMeasuredAsBlurred() throws {
    let pixelBuffer = try makeUniformPixelBuffer(value: 128)
    let result = FaceQualityEvaluator().evaluate([makeFace()], in: pixelBuffer)

    XCTAssertEqual(result.metrics.meanLuminance ?? 0, 0.502, accuracy: 0.01)
    XCTAssertEqual(result.metrics.sharpness ?? 1, 0, accuracy: 0.0001)
    XCTAssertTrue(
      result.issues.contains { issue in
        if case .blurred = issue { return true }
        return false
      })
  }

  func testRejectsInvalidPolicyValues() {
    XCTAssertThrowsError(try FaceQualityPolicy(minimumConfidence: 1.1)) {
      error in
      XCTAssertEqual(error as? FaceQualityPolicyError, .invalidConfidence)
    }
    XCTAssertThrowsError(
      try FaceQualityPolicy(minimumLuminance: 0.9, maximumLuminance: 0.2)
    ) { error in
      XCTAssertEqual(error as? FaceQualityPolicyError, .invalidLuminanceRange)
    }
  }

  private func makeFace() -> DetectedFace {
    DetectedFace(
      boundingBox: CGRect(x: 0.2, y: 0.2, width: 0.6, height: 0.6),
      confidence: 0.99,
      roll: 0,
      yaw: 0,
      pitch: 0,
      landmarks: FaceLandmarks(
        leftEye: [NormalizedFacePoint(x: 0.3, y: 0.7)],
        rightEye: [NormalizedFacePoint(x: 0.7, y: 0.7)],
        nose: [NormalizedFacePoint(x: 0.5, y: 0.5)],
        outerLips: [
          NormalizedFacePoint(x: 0.35, y: 0.3),
          NormalizedFacePoint(x: 0.65, y: 0.3),
        ]
      )
    )
  }

  private func makeUniformPixelBuffer(value: UInt8) throws -> CVPixelBuffer {
    var pixelBuffer: CVPixelBuffer?
    let status = CVPixelBufferCreate(
      kCFAllocatorDefault,
      128,
      128,
      kCVPixelFormatType_32BGRA,
      nil,
      &pixelBuffer
    )
    guard status == kCVReturnSuccess, let pixelBuffer else {
      throw TestError.cannotCreatePixelBuffer
    }

    CVPixelBufferLockBaseAddress(pixelBuffer, [])
    defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }
    guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
      throw TestError.cannotCreatePixelBuffer
    }
    let bytes = baseAddress.assumingMemoryBound(to: UInt8.self)
    let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
    for y in 0..<CVPixelBufferGetHeight(pixelBuffer) {
      for x in 0..<CVPixelBufferGetWidth(pixelBuffer) {
        let offset = y * bytesPerRow + x * 4
        bytes[offset] = value
        bytes[offset + 1] = value
        bytes[offset + 2] = value
        bytes[offset + 3] = 255
      }
    }
    return pixelBuffer
  }
}

private enum TestError: Error {
  case cannotCreatePixelBuffer
}
