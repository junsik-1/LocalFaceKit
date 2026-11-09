import CoreML
import CoreVideo
import Foundation

public struct FaceImageSize: Equatable, Sendable {
  public let width: Int
  public let height: Int

  public init(width: Int, height: Int) {
    self.width = width
    self.height = height
  }
}

/// Runs a face embedding model whose input is an image and output is an MLMultiArray.
/// The pixel buffer must already be cropped, aligned, and sized for the model.
public actor CoreMLFaceEmbedder {
  private let model: MLModel
  private let inputName: String
  private let outputName: String
  public nonisolated let modelIdentifier: String
  public nonisolated let inputImageSize: FaceImageSize

  public init(
    modelURL: URL,
    modelIdentifier: String,
    inputName: String = "image",
    outputName: String = "embedding",
    computeUnits: MLComputeUnits = .all
  ) throws {
    guard modelURL.isFileURL else {
      throw CoreMLFaceEmbedderError.modelMustBeLocal
    }
    let configuration = MLModelConfiguration()
    configuration.computeUnits = computeUnits
    let model = try MLModel(contentsOf: modelURL, configuration: configuration)
    guard let inputDescription = model.modelDescription.inputDescriptionsByName[inputName]
    else {
      throw CoreMLFaceEmbedderError.missingInput(inputName)
    }
    guard inputDescription.type == .image, let imageConstraint = inputDescription.imageConstraint
    else {
      throw CoreMLFaceEmbedderError.inputMustBeImage(inputName)
    }

    self.model = model
    self.modelIdentifier = modelIdentifier
    self.inputName = inputName
    self.outputName = outputName
    self.inputImageSize = FaceImageSize(
      width: imageConstraint.pixelsWide,
      height: imageConstraint.pixelsHigh
    )
  }

  public nonisolated func embedding(
    for alignedFace: CVPixelBuffer
  ) async throws -> FaceEmbedding {
    try await embedding(for: SendablePixelBuffer(value: alignedFace))
  }

  func embedding(for alignedFace: SendablePixelBuffer) throws -> FaceEmbedding {
    let actualSize = FaceImageSize(
      width: CVPixelBufferGetWidth(alignedFace.value),
      height: CVPixelBufferGetHeight(alignedFace.value)
    )
    guard actualSize == inputImageSize else {
      throw CoreMLFaceEmbedderError.inputSizeMismatch(
        expected: inputImageSize,
        actual: actualSize
      )
    }
    let input = try MLDictionaryFeatureProvider(dictionary: [
      inputName: MLFeatureValue(pixelBuffer: alignedFace.value)
    ])
    let prediction = try model.prediction(from: input)
    guard let array = prediction.featureValue(for: outputName)?.multiArrayValue else {
      throw CoreMLFaceEmbedderError.missingOutput(outputName)
    }

    let values = (0..<array.count).map { index in
      array[index].floatValue
    }
    return try FaceEmbedding(values)
  }
}

public enum CoreMLFaceEmbedderError: Error, Equatable, Sendable {
  case modelMustBeLocal
  case missingInput(String)
  case inputMustBeImage(String)
  case inputSizeMismatch(expected: FaceImageSize, actual: FaceImageSize)
  case missingOutput(String)
}
