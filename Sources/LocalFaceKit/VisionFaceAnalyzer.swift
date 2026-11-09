import CoreGraphics
import CoreVideo
import Foundation
import ImageIO
import Vision

public struct NormalizedFacePoint: Codable, Equatable, Sendable {
  public let x: Float
  public let y: Float

  public init(x: Float, y: Float) {
    self.x = x
    self.y = y
  }
}

public struct FaceLandmarks: Codable, Equatable, Sendable {
  public let faceContour: [NormalizedFacePoint]
  public let leftEye: [NormalizedFacePoint]
  public let rightEye: [NormalizedFacePoint]
  public let leftEyebrow: [NormalizedFacePoint]
  public let rightEyebrow: [NormalizedFacePoint]
  public let leftPupil: [NormalizedFacePoint]
  public let rightPupil: [NormalizedFacePoint]
  public let nose: [NormalizedFacePoint]
  public let noseCrest: [NormalizedFacePoint]
  public let medianLine: [NormalizedFacePoint]
  public let outerLips: [NormalizedFacePoint]
  public let innerLips: [NormalizedFacePoint]

  public init(
    faceContour: [NormalizedFacePoint] = [],
    leftEye: [NormalizedFacePoint] = [],
    rightEye: [NormalizedFacePoint] = [],
    leftEyebrow: [NormalizedFacePoint] = [],
    rightEyebrow: [NormalizedFacePoint] = [],
    leftPupil: [NormalizedFacePoint] = [],
    rightPupil: [NormalizedFacePoint] = [],
    nose: [NormalizedFacePoint] = [],
    noseCrest: [NormalizedFacePoint] = [],
    medianLine: [NormalizedFacePoint] = [],
    outerLips: [NormalizedFacePoint] = [],
    innerLips: [NormalizedFacePoint] = []
  ) {
    self.faceContour = faceContour
    self.leftEye = leftEye
    self.rightEye = rightEye
    self.leftEyebrow = leftEyebrow
    self.rightEyebrow = rightEyebrow
    self.leftPupil = leftPupil
    self.rightPupil = rightPupil
    self.nose = nose
    self.noseCrest = noseCrest
    self.medianLine = medianLine
    self.outerLips = outerLips
    self.innerLips = innerLips
  }
}

public struct DetectedFace: Equatable, Sendable {
  public let boundingBox: CGRect
  public let confidence: Float
  public let roll: Float?
  public let yaw: Float?
  public let pitch: Float?
  public let landmarks: FaceLandmarks?

  public init(
    boundingBox: CGRect,
    confidence: Float,
    roll: Float? = nil,
    yaw: Float? = nil,
    pitch: Float? = nil,
    landmarks: FaceLandmarks? = nil
  ) {
    self.boundingBox = boundingBox
    self.confidence = confidence
    self.roll = roll
    self.yaw = yaw
    self.pitch = pitch
    self.landmarks = landmarks
  }
}

/// Serializes Vision requests off the caller's actor.
public actor VisionFaceAnalyzer {
  public init() {}

  public nonisolated func analyze(
    pixelBuffer: CVPixelBuffer,
    orientation: CGImagePropertyOrientation = .up,
    includeLandmarks: Bool = true
  ) async throws -> [DetectedFace] {
    try await analyze(
      imageBuffer: SendablePixelBuffer(value: pixelBuffer),
      orientation: orientation,
      includeLandmarks: includeLandmarks
    )
  }

  func analyze(
    imageBuffer: SendablePixelBuffer,
    orientation: CGImagePropertyOrientation,
    includeLandmarks: Bool
  ) throws -> [DetectedFace] {
    let handler = VNImageRequestHandler(
      cvPixelBuffer: imageBuffer.value,
      orientation: orientation,
      options: [:]
    )

    if includeLandmarks {
      let request = VNDetectFaceLandmarksRequest()
      try handler.perform([request])
      return (request.results ?? []).map(Self.makeDetectedFace)
    }

    let request = VNDetectFaceRectanglesRequest()
    try handler.perform([request])
    return (request.results ?? []).map(Self.makeDetectedFace)
  }

  private static func makeDetectedFace(_ observation: VNFaceObservation) -> DetectedFace {
    DetectedFace(
      boundingBox: observation.boundingBox,
      confidence: observation.confidence,
      roll: observation.roll?.floatValue,
      yaw: observation.yaw?.floatValue,
      pitch: observation.pitch?.floatValue,
      landmarks: observation.landmarks.map(makeLandmarks)
    )
  }

  private static func makeLandmarks(_ landmarks: VNFaceLandmarks2D) -> FaceLandmarks {
    FaceLandmarks(
      faceContour: points(landmarks.faceContour),
      leftEye: points(landmarks.leftEye),
      rightEye: points(landmarks.rightEye),
      leftEyebrow: points(landmarks.leftEyebrow),
      rightEyebrow: points(landmarks.rightEyebrow),
      leftPupil: points(landmarks.leftPupil),
      rightPupil: points(landmarks.rightPupil),
      nose: points(landmarks.nose),
      noseCrest: points(landmarks.noseCrest),
      medianLine: points(landmarks.medianLine),
      outerLips: points(landmarks.outerLips),
      innerLips: points(landmarks.innerLips)
    )
  }

  private static func points(_ region: VNFaceLandmarkRegion2D?) -> [NormalizedFacePoint] {
    region?.normalizedPoints.map {
      NormalizedFacePoint(x: Float($0.x), y: Float($0.y))
    } ?? []
  }
}
