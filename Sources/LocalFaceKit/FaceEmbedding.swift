import Foundation

/// A unit-length feature vector produced by a face embedding model.
public struct FaceEmbedding: Codable, Equatable, Sendable {
  public let values: [Float]

  /// Creates an embedding and normalizes it to unit length.
  public init(_ values: [Float]) throws {
    guard !values.isEmpty else {
      throw FaceEmbeddingError.empty
    }
    guard values.allSatisfy(\.isFinite) else {
      throw FaceEmbeddingError.nonFiniteValue
    }

    let squaredNorm = values.reduce(Float.zero) { partial, value in
      partial + (value * value)
    }
    guard squaredNorm > Float.ulpOfOne else {
      throw FaceEmbeddingError.zeroNorm
    }

    let norm = sqrt(squaredNorm)
    self.values = values.map { $0 / norm }
  }

  public var dimension: Int { values.count }

  public func cosineSimilarity(to other: FaceEmbedding) throws -> Float {
    guard dimension == other.dimension else {
      throw FaceEmbeddingError.dimensionMismatch(
        expected: dimension,
        actual: other.dimension
      )
    }

    return zip(values, other.values).reduce(Float.zero) { partial, pair in
      partial + (pair.0 * pair.1)
    }
  }
}

public enum FaceEmbeddingError: Error, Equatable, Sendable {
  case empty
  case nonFiniteValue
  case zeroNorm
  case dimensionMismatch(expected: Int, actual: Int)
}
