import CoreML
import CoreVideo
import Foundation

/// Runs a face embedding model whose input is an image and output is an MLMultiArray.
/// The pixel buffer must already be cropped, aligned, and sized for the model.
public actor CoreMLFaceEmbedder {
  private let model: MLModel
  private let inputName: String
  private let outputName: String
  public let modelIdentifier: String

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
    self.model = try MLModel(contentsOf: modelURL, configuration: configuration)
    self.modelIdentifier = modelIdentifier
    self.inputName = inputName
    self.outputName = outputName
  }

  public func embedding(for alignedFace: CVPixelBuffer) throws -> FaceEmbedding {
    let input = try MLDictionaryFeatureProvider(dictionary: [
      inputName: MLFeatureValue(pixelBuffer: alignedFace)
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
  case missingOutput(String)
}
