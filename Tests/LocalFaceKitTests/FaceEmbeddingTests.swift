import Testing

@testable import LocalFaceKit

@Test func embeddingIsNormalized() throws {
  let embedding = try FaceEmbedding([3, 4])

  #expect(abs(embedding.values[0] - 0.6) < 0.0001)
  #expect(abs(embedding.values[1] - 0.8) < 0.0001)
}

@Test func embeddingRejectsInvalidInput() {
  #expect(throws: FaceEmbeddingError.empty) {
    try FaceEmbedding([])
  }
  #expect(throws: FaceEmbeddingError.zeroNorm) {
    try FaceEmbedding([0, 0])
  }
}

@Test func cosineSimilarityRequiresMatchingDimensions() throws {
  let first = try FaceEmbedding([1, 0])
  let second = try FaceEmbedding([1, 0, 0])

  #expect(throws: FaceEmbeddingError.dimensionMismatch(expected: 2, actual: 3)) {
    try first.cosineSimilarity(to: second)
  }
}
