import CoreGraphics
import CoreImage
import CoreVideo
import Foundation
import ImageIO

public struct FaceQualityPolicy: Equatable, Sendable {
  public let minimumConfidence: Float
  public let minimumFaceArea: Float
  public let edgeMargin: Float
  public let maximumYaw: Float
  public let maximumRoll: Float
  public let maximumPitch: Float
  public let requireLandmarks: Bool
  public let minimumLuminance: Float
  public let maximumLuminance: Float
  public let minimumSharpness: Float

  public static let standard = FaceQualityPolicy(
    minimumConfidence: 0.7,
    minimumFaceArea: 0.08,
    edgeMargin: 0.015,
    maximumYaw: 0.35,
    maximumRoll: 0.30,
    maximumPitch: 0.35,
    requireLandmarks: true,
    minimumLuminance: 0.12,
    maximumLuminance: 0.92,
    minimumSharpness: 0.015,
    validated: ()
  )

  public init(
    minimumConfidence: Float = 0.7,
    minimumFaceArea: Float = 0.08,
    edgeMargin: Float = 0.015,
    maximumYaw: Float = 0.35,
    maximumRoll: Float = 0.30,
    maximumPitch: Float = 0.35,
    requireLandmarks: Bool = true,
    minimumLuminance: Float = 0.12,
    maximumLuminance: Float = 0.92,
    minimumSharpness: Float = 0.015
  ) throws {
    guard (0...1).contains(minimumConfidence) else {
      throw FaceQualityPolicyError.invalidConfidence
    }
    guard (0...1).contains(minimumFaceArea) else {
      throw FaceQualityPolicyError.invalidFaceArea
    }
    guard (0..<0.5).contains(edgeMargin) else {
      throw FaceQualityPolicyError.invalidEdgeMargin
    }
    guard maximumYaw >= 0, maximumRoll >= 0, maximumPitch >= 0 else {
      throw FaceQualityPolicyError.invalidPoseLimit
    }
    guard (0...1).contains(minimumLuminance),
      (0...1).contains(maximumLuminance),
      minimumLuminance < maximumLuminance
    else {
      throw FaceQualityPolicyError.invalidLuminanceRange
    }
    guard minimumSharpness >= 0 else {
      throw FaceQualityPolicyError.invalidSharpness
    }
    self.init(
      minimumConfidence: minimumConfidence,
      minimumFaceArea: minimumFaceArea,
      edgeMargin: edgeMargin,
      maximumYaw: maximumYaw,
      maximumRoll: maximumRoll,
      maximumPitch: maximumPitch,
      requireLandmarks: requireLandmarks,
      minimumLuminance: minimumLuminance,
      maximumLuminance: maximumLuminance,
      minimumSharpness: minimumSharpness,
      validated: ()
    )
  }

  private init(
    minimumConfidence: Float,
    minimumFaceArea: Float,
    edgeMargin: Float,
    maximumYaw: Float,
    maximumRoll: Float,
    maximumPitch: Float,
    requireLandmarks: Bool,
    minimumLuminance: Float,
    maximumLuminance: Float,
    minimumSharpness: Float,
    validated: Void
  ) {
    self.minimumConfidence = minimumConfidence
    self.minimumFaceArea = minimumFaceArea
    self.edgeMargin = edgeMargin
    self.maximumYaw = maximumYaw
    self.maximumRoll = maximumRoll
    self.maximumPitch = maximumPitch
    self.requireLandmarks = requireLandmarks
    self.minimumLuminance = minimumLuminance
    self.maximumLuminance = maximumLuminance
    self.minimumSharpness = minimumSharpness
  }
}

public enum FaceQualityPolicyError: Error, Equatable, Sendable {
  case invalidConfidence
  case invalidFaceArea
  case invalidEdgeMargin
  case invalidPoseLimit
  case invalidLuminanceRange
  case invalidSharpness
}

public enum FaceQualityIssue: Equatable, Sendable {
  case noFace
  case multipleFaces(count: Int)
  case lowConfidence(actual: Float, minimum: Float)
  case faceTooSmall(actual: Float, minimum: Float)
  case faceClipped
  case excessiveYaw(actual: Float, maximum: Float)
  case excessiveRoll(actual: Float, maximum: Float)
  case excessivePitch(actual: Float, maximum: Float)
  case missingLandmarks
  case poorIllumination(actual: Float, minimum: Float, maximum: Float)
  case blurred(actual: Float, minimum: Float)
}

public struct FaceQualityMetrics: Equatable, Sendable {
  public let faceArea: Float?
  public let meanLuminance: Float?
  public let sharpness: Float?

  public init(
    faceArea: Float? = nil,
    meanLuminance: Float? = nil,
    sharpness: Float? = nil
  ) {
    self.faceArea = faceArea
    self.meanLuminance = meanLuminance
    self.sharpness = sharpness
  }
}

public struct FaceQualityResult: Equatable, Sendable {
  public let face: DetectedFace?
  public let issues: [FaceQualityIssue]
  public let metrics: FaceQualityMetrics

  public var isAccepted: Bool { issues.isEmpty && face != nil }

  public init(
    face: DetectedFace?,
    issues: [FaceQualityIssue],
    metrics: FaceQualityMetrics
  ) {
    self.face = face
    self.issues = issues
    self.metrics = metrics
  }
}

/// Applies deterministic enrollment and verification quality gates.
///
/// When a pixel buffer is supplied, a small in-memory face crop is used to
/// estimate illumination and sharpness. No frame or crop is persisted.
public final class FaceQualityEvaluator: @unchecked Sendable {
  public let policy: FaceQualityPolicy

  private let context: CIContext
  private let sampleSize = 64

  public init(policy: FaceQualityPolicy = .standard) {
    self.policy = policy
    self.context = CIContext(options: [.cacheIntermediates: false])
  }

  public func evaluate(
    _ faces: [DetectedFace],
    in pixelBuffer: CVPixelBuffer? = nil,
    orientation: CGImagePropertyOrientation = .up
  ) -> FaceQualityResult {
    guard faces.count == 1, let face = faces.first else {
      let issue: FaceQualityIssue =
        faces.isEmpty
        ? .noFace
        : .multipleFaces(count: faces.count)
      return FaceQualityResult(
        face: nil,
        issues: [issue],
        metrics: FaceQualityMetrics()
      )
    }

    let area = Float(face.boundingBox.width * face.boundingBox.height)
    var issues = geometricIssues(for: face, area: area)
    var luminance: Float?
    var sharpness: Float?

    if let pixelBuffer,
      let imageMetrics = imageMetrics(
        pixelBuffer: pixelBuffer,
        face: face,
        orientation: orientation
      )
    {
      luminance = imageMetrics.luminance
      sharpness = imageMetrics.sharpness
      if imageMetrics.luminance < policy.minimumLuminance
        || imageMetrics.luminance > policy.maximumLuminance
      {
        issues.append(
          .poorIllumination(
            actual: imageMetrics.luminance,
            minimum: policy.minimumLuminance,
            maximum: policy.maximumLuminance
          )
        )
      }
      if imageMetrics.sharpness < policy.minimumSharpness {
        issues.append(
          .blurred(actual: imageMetrics.sharpness, minimum: policy.minimumSharpness)
        )
      }
    }

    return FaceQualityResult(
      face: face,
      issues: issues,
      metrics: FaceQualityMetrics(
        faceArea: area,
        meanLuminance: luminance,
        sharpness: sharpness
      )
    )
  }

  private func geometricIssues(
    for face: DetectedFace,
    area: Float
  ) -> [FaceQualityIssue] {
    var issues: [FaceQualityIssue] = []
    if face.confidence < policy.minimumConfidence {
      issues.append(
        .lowConfidence(actual: face.confidence, minimum: policy.minimumConfidence)
      )
    }
    if area < policy.minimumFaceArea {
      issues.append(.faceTooSmall(actual: area, minimum: policy.minimumFaceArea))
    }

    let margin = CGFloat(policy.edgeMargin)
    if face.boundingBox.minX < margin
      || face.boundingBox.minY < margin
      || face.boundingBox.maxX > 1 - margin
      || face.boundingBox.maxY > 1 - margin
    {
      issues.append(.faceClipped)
    }
    if let yaw = face.yaw, abs(yaw) > policy.maximumYaw {
      issues.append(.excessiveYaw(actual: yaw, maximum: policy.maximumYaw))
    }
    if let roll = face.roll, abs(roll) > policy.maximumRoll {
      issues.append(.excessiveRoll(actual: roll, maximum: policy.maximumRoll))
    }
    if let pitch = face.pitch, abs(pitch) > policy.maximumPitch {
      issues.append(.excessivePitch(actual: pitch, maximum: policy.maximumPitch))
    }
    if policy.requireLandmarks && !Self.hasFivePointLandmarks(face.landmarks) {
      issues.append(.missingLandmarks)
    }
    return issues
  }

  private static func hasFivePointLandmarks(_ landmarks: FaceLandmarks?) -> Bool {
    guard let landmarks else { return false }
    let hasLeftEye = !landmarks.leftPupil.isEmpty || !landmarks.leftEye.isEmpty
    let hasRightEye = !landmarks.rightPupil.isEmpty || !landmarks.rightEye.isEmpty
    return hasLeftEye && hasRightEye
      && (!landmarks.nose.isEmpty || !landmarks.noseCrest.isEmpty)
      && landmarks.outerLips.count >= 2
  }

  private func imageMetrics(
    pixelBuffer: CVPixelBuffer,
    face: DetectedFace,
    orientation: CGImagePropertyOrientation
  ) -> (luminance: Float, sharpness: Float)? {
    let orientedImage = CIImage(cvPixelBuffer: pixelBuffer)
      .oriented(forExifOrientation: Int32(orientation.rawValue))
    let image = orientedImage.transformed(
      by: CGAffineTransform(
        translationX: -orientedImage.extent.minX,
        y: -orientedImage.extent.minY
      )
    )
    let faceBounds = CGRect(
      x: image.extent.width * face.boundingBox.minX,
      y: image.extent.height * face.boundingBox.minY,
      width: image.extent.width * face.boundingBox.width,
      height: image.extent.height * face.boundingBox.height
    ).intersection(image.extent)
    guard !faceBounds.isNull, faceBounds.width >= 2, faceBounds.height >= 2 else {
      return nil
    }

    let translated = image.cropped(to: faceBounds).transformed(
      by: CGAffineTransform(translationX: -faceBounds.minX, y: -faceBounds.minY)
    )
    let scaled = translated.transformed(
      by: CGAffineTransform(
        scaleX: CGFloat(sampleSize) / faceBounds.width,
        y: CGFloat(sampleSize) / faceBounds.height
      )
    )
    let bounds = CGRect(x: 0, y: 0, width: sampleSize, height: sampleSize)
    let rowBytes = sampleSize * 4
    var pixels = [UInt8](repeating: 0, count: rowBytes * sampleSize)
    pixels.withUnsafeMutableBytes { bytes in
      guard let address = bytes.baseAddress else { return }
      context.render(
        scaled,
        toBitmap: address,
        rowBytes: rowBytes,
        bounds: bounds,
        format: .BGRA8,
        colorSpace: CGColorSpaceCreateDeviceRGB()
      )
    }

    var luma = [Float](repeating: 0, count: sampleSize * sampleSize)
    var sum: Float = 0
    for index in luma.indices {
      let offset = index * 4
      let blue = Float(pixels[offset]) / 255
      let green = Float(pixels[offset + 1]) / 255
      let red = Float(pixels[offset + 2]) / 255
      let value = 0.2126 * red + 0.7152 * green + 0.0722 * blue
      luma[index] = value
      sum += value
    }

    var laplacianSum: Float = 0
    var laplacianCount = 0
    for y in 1..<(sampleSize - 1) {
      for x in 1..<(sampleSize - 1) {
        let index = y * sampleSize + x
        let laplacian =
          4 * luma[index]
          - luma[index - 1]
          - luma[index + 1]
          - luma[index - sampleSize]
          - luma[index + sampleSize]
        laplacianSum += abs(laplacian)
        laplacianCount += 1
      }
    }

    return (
      luminance: sum / Float(luma.count),
      sharpness: laplacianSum / Float(laplacianCount)
    )
  }
}
