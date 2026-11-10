import Foundation

/// Collects quality-approved embeddings from one live camera session.
/// Use capture timestamps in seconds, rather than wall-clock time. This value
/// does not retain images, persist templates, or establish liveness.
public struct FaceEnrollmentSession: Sendable {
  public let modelIdentifier: String
  public let requiredSampleCount: Int
  public let minimumSampleInterval: TimeInterval
  public private(set) var embeddings: [FaceEmbedding] = []
  private var lastSampleTimestamp: TimeInterval?

  public init(
    modelIdentifier: String,
    requiredSampleCount: Int = 5,
    minimumSampleInterval: TimeInterval = 0.4
  ) throws {
    guard !modelIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw FaceTemplateError.emptyModelIdentifier
    }
    guard (2...30).contains(requiredSampleCount) else {
      throw FaceEnrollmentError.invalidSampleCount
    }
    guard minimumSampleInterval.isFinite, minimumSampleInterval > 0 else {
      throw FaceEnrollmentError.invalidSampleInterval
    }
    self.modelIdentifier = modelIdentifier
    self.requiredSampleCount = requiredSampleCount
    self.minimumSampleInterval = minimumSampleInterval
  }

  public var isComplete: Bool { embeddings.count == requiredSampleCount }
  public var progress: Double { Double(embeddings.count) / Double(requiredSampleCount) }

  /// Call only for `.accepted` pipeline results. Check the pipeline's model ID
  /// on every sample so embeddings from different models cannot be mixed.
  /// Returns false when a sample is too close in time or collection is complete.
  @discardableResult
  public mutating func append(
    _ embedding: FaceEmbedding,
    modelIdentifier: String,
    timestamp: TimeInterval
  ) throws -> Bool {
    guard modelIdentifier == self.modelIdentifier else {
      throw FaceMatcherError.modelMismatch
    }
    guard timestamp.isFinite, timestamp >= 0 else {
      throw FaceEnrollmentError.invalidTimestamp
    }
    if let first = embeddings.first, first.dimension != embedding.dimension {
      throw FaceTemplateError.inconsistentDimensions
    }
    guard !isComplete else { return false }
    if let lastSampleTimestamp {
      guard timestamp >= lastSampleTimestamp else {
        throw FaceEnrollmentError.nonMonotonicTimestamp
      }
      guard timestamp - lastSampleTimestamp >= minimumSampleInterval else { return false }
    }
    embeddings.append(embedding)
    lastSampleTimestamp = timestamp
    return true
  }

  /// The caller persists the completed template after user confirmation.
  public func template(subjectID: String) throws -> FaceTemplate {
    guard isComplete else { throw FaceEnrollmentError.incomplete }
    return try FaceTemplate(
      subjectID: subjectID,
      modelIdentifier: modelIdentifier,
      embeddings: embeddings
    )
  }

  /// Discards collected embeddings when cancelled or before a new camera run.
  public mutating func reset() {
    embeddings.removeAll(keepingCapacity: false)
    lastSampleTimestamp = nil
  }
}

public enum FaceEnrollmentError: Error, Equatable, Sendable {
  case invalidSampleCount
  case invalidSampleInterval
  case invalidTimestamp
  case nonMonotonicTimestamp
  case incomplete
}
