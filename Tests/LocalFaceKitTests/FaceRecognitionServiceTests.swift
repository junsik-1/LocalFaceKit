import Testing

@testable import LocalFaceKit

@Test func serviceEnrollsAndIdentifies() async throws {
  let store = InMemoryTemplateStore()
  let service = FaceRecognitionService(
    modelIdentifier: "test-v1",
    store: store,
    matchingPolicy: try MatchingPolicy(threshold: 0.75)
  )

  try await service.enroll(
    subjectID: "alice",
    embeddings: [FaceEmbedding([1, 0])]
  )
  let result = try await service.identify(FaceEmbedding([0.98, 0.02]))

  #expect(result.decision == .match)
  #expect(result.subjectID == "alice")
}
