import Foundation

/// On-device biometric template. It contains embeddings, never source images.
public struct FaceTemplate: Codable, Equatable, Identifiable, Sendable {
  public var id: String { subjectID }

  public let subjectID: String
  public let modelIdentifier: String
  public let embeddings: [FaceEmbedding]
  public let createdAt: Date
  public let updatedAt: Date

  public init(
    subjectID: String,
    modelIdentifier: String,
    embeddings: [FaceEmbedding],
    createdAt: Date = Date(),
    updatedAt: Date = Date()
  ) throws {
    guard !subjectID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw FaceTemplateError.emptySubjectID
    }
    guard !modelIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw FaceTemplateError.emptyModelIdentifier
    }
    guard let dimension = embeddings.first?.dimension else {
      throw FaceTemplateError.noEmbeddings
    }
    guard embeddings.allSatisfy({ $0.dimension == dimension }) else {
      throw FaceTemplateError.inconsistentDimensions
    }

    self.subjectID = subjectID
    self.modelIdentifier = modelIdentifier
    self.embeddings = embeddings
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }

  /// Returns the normalized mean of all enrollment samples.
  public func centroid() throws -> FaceEmbedding {
    guard let dimension = embeddings.first?.dimension else {
      throw FaceTemplateError.noEmbeddings
    }

    var mean = Array(repeating: Float.zero, count: dimension)
    for embedding in embeddings {
      for index in mean.indices {
        mean[index] += embedding.values[index]
      }
    }
    let count = Float(embeddings.count)
    return try FaceEmbedding(mean.map { $0 / count })
  }
}

public enum FaceTemplateError: Error, Equatable, Sendable {
  case emptySubjectID
  case emptyModelIdentifier
  case noEmbeddings
  case inconsistentDimensions
}
