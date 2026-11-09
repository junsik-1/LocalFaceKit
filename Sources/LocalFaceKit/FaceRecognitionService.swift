import Foundation

/// High-level enrollment, verification, and identification service.
public actor FaceRecognitionService {
  private let store: any FaceTemplateStoring
  private let matcher: CosineFaceMatcher
  public let modelIdentifier: String

  public init(
    modelIdentifier: String,
    store: any FaceTemplateStoring,
    matchingPolicy: MatchingPolicy
  ) {
    self.modelIdentifier = modelIdentifier
    self.store = store
    self.matcher = CosineFaceMatcher(policy: matchingPolicy)
  }

  public func enroll(subjectID: String, embeddings: [FaceEmbedding]) async throws {
    let template = try FaceTemplate(
      subjectID: subjectID,
      modelIdentifier: modelIdentifier,
      embeddings: embeddings
    )
    try await store.save(template)
  }

  public func verify(
    _ query: FaceEmbedding,
    claimedSubjectID: String
  ) async throws -> FaceMatch {
    guard let template = try await store.template(for: claimedSubjectID) else {
      throw FaceRecognitionServiceError.subjectNotFound
    }
    return try matcher.verify(
      query,
      against: template,
      modelIdentifier: modelIdentifier
    )
  }

  public func identify(_ query: FaceEmbedding) async throws -> FaceMatch {
    let templates = try await store.allTemplates()
    return try matcher.identify(
      query,
      among: templates,
      modelIdentifier: modelIdentifier
    )
  }

  public func remove(subjectID: String) async throws {
    try await store.remove(subjectID: subjectID)
  }

  public func removeAll() async throws {
    try await store.removeAll()
  }
}

public enum FaceRecognitionServiceError: Error, Equatable, Sendable {
  case subjectNotFound
}
