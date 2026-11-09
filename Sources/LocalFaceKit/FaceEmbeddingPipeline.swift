import CoreVideo
import Foundation
import ImageIO

public enum FaceEmbeddingPipelineResult: Equatable, Sendable {
  case rejected(FaceQualityResult)
  case accepted(embedding: FaceEmbedding, quality: FaceQualityResult)

  public var embedding: FaceEmbedding? {
    guard case .accepted(let embedding, _) = self else { return nil }
    return embedding
  }

  public var quality: FaceQualityResult {
    switch self {
    case .rejected(let quality), .accepted(_, let quality):
      quality
    }
  }
}

/// Runs the complete local face preprocessing and embedding path for one frame.
/// Rejected frames never reach Core ML, and no source image is retained.
public final class FaceEmbeddingPipeline: Sendable {
  public let modelIdentifier: String

  private let analyzer: VisionFaceAnalyzer
  private let qualityEvaluator: FaceQualityEvaluator
  private let aligner: FivePointFaceAligner
  private let embedder: CoreMLFaceEmbedder

  public init(
    analyzer: VisionFaceAnalyzer = VisionFaceAnalyzer(),
    qualityEvaluator: FaceQualityEvaluator = FaceQualityEvaluator(),
    aligner: FivePointFaceAligner,
    embedder: CoreMLFaceEmbedder
  ) throws {
    let alignedSize = FaceImageSize(
      width: aligner.outputSize,
      height: aligner.outputSize
    )
    guard alignedSize == embedder.inputImageSize else {
      throw FaceEmbeddingPipelineError.inputSizeMismatch(
        aligner: alignedSize,
        model: embedder.inputImageSize
      )
    }
    self.modelIdentifier = embedder.modelIdentifier
    self.analyzer = analyzer
    self.qualityEvaluator = qualityEvaluator
    self.aligner = aligner
    self.embedder = embedder
  }

  public func process(
    pixelBuffer: CVPixelBuffer,
    orientation: CGImagePropertyOrientation = .up
  ) async throws -> FaceEmbeddingPipelineResult {
    let imageBuffer = SendablePixelBuffer(value: pixelBuffer)
    let faces = try await analyzer.analyze(
      imageBuffer: imageBuffer,
      orientation: orientation,
      includeLandmarks: true
    )
    let quality = qualityEvaluator.evaluate(
      faces,
      in: imageBuffer.value,
      orientation: orientation
    )
    guard quality.isAccepted, let face = quality.face else {
      return .rejected(quality)
    }

    let alignedFace = try aligner.align(
      pixelBuffer: imageBuffer.value,
      face: face,
      orientation: orientation
    )
    let embedding = try await embedder.embedding(
      for: SendablePixelBuffer(value: alignedFace)
    )
    return .accepted(embedding: embedding, quality: quality)
  }
}

public enum FaceEmbeddingPipelineError: Error, Equatable, Sendable {
  case inputSizeMismatch(aligner: FaceImageSize, model: FaceImageSize)
}
