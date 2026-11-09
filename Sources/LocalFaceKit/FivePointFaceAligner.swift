import CoreGraphics
import CoreImage
import CoreVideo
import Foundation
import ImageIO

/// Five image-space anchors used to normalize a face before embedding.
/// Coordinates use Vision's normalized, lower-left image coordinate system.
public struct FivePointFaceLandmarks: Equatable, Sendable {
  public let leftEye: NormalizedFacePoint
  public let rightEye: NormalizedFacePoint
  public let nose: NormalizedFacePoint
  public let leftMouth: NormalizedFacePoint
  public let rightMouth: NormalizedFacePoint

  fileprivate var points: [NormalizedFacePoint] {
    [leftEye, rightEye, nose, leftMouth, rightMouth]
  }

  public init(
    leftEye: NormalizedFacePoint,
    rightEye: NormalizedFacePoint,
    nose: NormalizedFacePoint,
    leftMouth: NormalizedFacePoint,
    rightMouth: NormalizedFacePoint
  ) {
    self.leftEye = leftEye
    self.rightEye = rightEye
    self.nose = nose
    self.leftMouth = leftMouth
    self.rightMouth = rightMouth
  }
}

/// Aligns a detected face to the five-point ArcFace reference geometry.
///
/// Pass the same orientation used by `VisionFaceAnalyzer`. The output is a
/// square BGRA pixel buffer ready for a locally bundled image-input model.
public final class FivePointFaceAligner: @unchecked Sendable {
  public let outputSize: Int

  private let context: CIContext

  public init(outputSize: Int = 112) throws {
    guard outputSize > 0 else {
      throw FivePointFaceAlignerError.invalidOutputSize
    }
    self.outputSize = outputSize
    self.context = CIContext(options: [.cacheIntermediates: false])
  }

  public func align(
    pixelBuffer: CVPixelBuffer,
    face: DetectedFace,
    orientation: CGImagePropertyOrientation = .up
  ) throws -> CVPixelBuffer {
    let anchors = try Self.landmarks(for: face)
    let orientedImage = CIImage(cvPixelBuffer: pixelBuffer)
      .oriented(forExifOrientation: Int32(orientation.rawValue))
    let sourceImage = orientedImage.transformed(
      by: CGAffineTransform(
        translationX: -orientedImage.extent.minX,
        y: -orientedImage.extent.minY
      )
    )

    let sourcePoints = anchors.points.map { point in
      CGPoint(
        x: CGFloat(point.x) * sourceImage.extent.width,
        y: CGFloat(point.y) * sourceImage.extent.height
      )
    }
    let targetPoints = Self.referencePoints(outputSize: outputSize)
    let transform = try Self.similarityTransform(from: sourcePoints, to: targetPoints)
    let outputBounds = CGRect(x: 0, y: 0, width: outputSize, height: outputSize)
    let alignedImage =
      sourceImage
      .transformed(by: transform)
      .cropped(to: outputBounds)
    let output = try Self.makePixelBuffer(size: outputSize)

    context.render(
      alignedImage,
      to: output,
      bounds: outputBounds,
      colorSpace: CGColorSpaceCreateDeviceRGB()
    )
    return output
  }

  public static func landmarks(
    for face: DetectedFace
  ) throws -> FivePointFaceLandmarks {
    guard let landmarks = face.landmarks else {
      throw FivePointFaceAlignerError.missingLandmarks
    }

    let firstEye = center(of: landmarks.leftPupil).or(center(of: landmarks.leftEye))
    let secondEye = center(of: landmarks.rightPupil).or(center(of: landmarks.rightEye))
    guard let firstEye, let secondEye,
      let nose = center(of: landmarks.nose).or(center(of: landmarks.noseCrest)),
      landmarks.outerLips.count >= 2
    else {
      throw FivePointFaceAlignerError.missingLandmarks
    }

    let eyes = [firstEye, secondEye].sorted { $0.x < $1.x }
    guard let leftMouth = landmarks.outerLips.min(by: { $0.x < $1.x }),
      let rightMouth = landmarks.outerLips.max(by: { $0.x < $1.x })
    else {
      throw FivePointFaceAlignerError.missingLandmarks
    }

    return FivePointFaceLandmarks(
      leftEye: imagePoint(eyes[0], in: face.boundingBox),
      rightEye: imagePoint(eyes[1], in: face.boundingBox),
      nose: imagePoint(nose, in: face.boundingBox),
      leftMouth: imagePoint(leftMouth, in: face.boundingBox),
      rightMouth: imagePoint(rightMouth, in: face.boundingBox)
    )
  }

  static func similarityTransform(
    from source: [CGPoint],
    to target: [CGPoint]
  ) throws -> CGAffineTransform {
    guard source.count == target.count, source.count >= 2 else {
      throw FivePointFaceAlignerError.invalidGeometry
    }

    let sourceCenter = centroid(source)
    let targetCenter = centroid(target)
    var denominator: CGFloat = 0
    var real: CGFloat = 0
    var imaginary: CGFloat = 0

    for (sourcePoint, targetPoint) in zip(source, target) {
      let sourceX = sourcePoint.x - sourceCenter.x
      let sourceY = sourcePoint.y - sourceCenter.y
      let targetX = targetPoint.x - targetCenter.x
      let targetY = targetPoint.y - targetCenter.y
      denominator += sourceX * sourceX + sourceY * sourceY
      real += sourceX * targetX + sourceY * targetY
      imaginary += sourceX * targetY - sourceY * targetX
    }

    guard denominator > .ulpOfOne else {
      throw FivePointFaceAlignerError.invalidGeometry
    }
    let a = real / denominator
    let b = imaginary / denominator
    guard a.isFinite, b.isFinite, hypot(a, b) > .ulpOfOne else {
      throw FivePointFaceAlignerError.invalidGeometry
    }

    return CGAffineTransform(
      a: a,
      b: b,
      c: -b,
      d: a,
      tx: targetCenter.x - a * sourceCenter.x + b * sourceCenter.y,
      ty: targetCenter.y - b * sourceCenter.x - a * sourceCenter.y
    )
  }

  private static func center(
    of points: [NormalizedFacePoint]
  ) -> NormalizedFacePoint? {
    guard !points.isEmpty else { return nil }
    let sum = points.reduce((x: Float.zero, y: Float.zero)) { partial, point in
      (partial.x + point.x, partial.y + point.y)
    }
    return NormalizedFacePoint(
      x: sum.x / Float(points.count),
      y: sum.y / Float(points.count)
    )
  }

  private static func imagePoint(
    _ point: NormalizedFacePoint,
    in boundingBox: CGRect
  ) -> NormalizedFacePoint {
    NormalizedFacePoint(
      x: Float(boundingBox.minX + CGFloat(point.x) * boundingBox.width),
      y: Float(boundingBox.minY + CGFloat(point.y) * boundingBox.height)
    )
  }

  private static func referencePoints(outputSize: Int) -> [CGPoint] {
    let scale = CGFloat(outputSize) / 112
    // ArcFace's published template uses a top-left origin. Core Image and
    // Vision use a lower-left origin, so the y coordinates are flipped.
    return [
      CGPoint(x: 38.2946, y: 112 - 51.6963),
      CGPoint(x: 73.5318, y: 112 - 51.5014),
      CGPoint(x: 56.0252, y: 112 - 71.7366),
      CGPoint(x: 41.5493, y: 112 - 92.3655),
      CGPoint(x: 70.7299, y: 112 - 92.2041),
    ].map { CGPoint(x: $0.x * scale, y: $0.y * scale) }
  }

  private static func centroid(_ points: [CGPoint]) -> CGPoint {
    let sum = points.reduce(CGPoint.zero) { partial, point in
      CGPoint(x: partial.x + point.x, y: partial.y + point.y)
    }
    return CGPoint(
      x: sum.x / CGFloat(points.count),
      y: sum.y / CGFloat(points.count)
    )
  }

  private static func makePixelBuffer(size: Int) throws -> CVPixelBuffer {
    var pixelBuffer: CVPixelBuffer?
    let attributes: [CFString: Any] = [
      kCVPixelBufferCGImageCompatibilityKey: true,
      kCVPixelBufferCGBitmapContextCompatibilityKey: true,
      kCVPixelBufferIOSurfacePropertiesKey: [:],
    ]
    let status = CVPixelBufferCreate(
      kCFAllocatorDefault,
      size,
      size,
      kCVPixelFormatType_32BGRA,
      attributes as CFDictionary,
      &pixelBuffer
    )
    guard status == kCVReturnSuccess, let pixelBuffer else {
      throw FivePointFaceAlignerError.cannotCreatePixelBuffer(status)
    }
    return pixelBuffer
  }
}

public enum FivePointFaceAlignerError: Error, Equatable, Sendable {
  case invalidOutputSize
  case missingLandmarks
  case invalidGeometry
  case cannotCreatePixelBuffer(CVReturn)
}

extension Optional {
  fileprivate func or(_ fallback: @autoclosure () -> Wrapped?) -> Wrapped? {
    self ?? fallback()
  }
}
