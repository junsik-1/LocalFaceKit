import Foundation

public struct MatchingPolicy: Equatable, Sendable {
  public let threshold: Float
  public let minimumMargin: Float

  public init(threshold: Float, minimumMargin: Float = 0) throws {
    guard (-1...1).contains(threshold) else {
      throw MatchingPolicyError.invalidThreshold
    }
    guard (0...2).contains(minimumMargin) else {
      throw MatchingPolicyError.invalidMargin
    }
    self.threshold = threshold
    self.minimumMargin = minimumMargin
  }
}

public enum MatchingPolicyError: Error, Equatable, Sendable {
  case invalidThreshold
  case invalidMargin
}

public enum MatchDecision: String, Codable, Equatable, Sendable {
  case match
  case noMatch
  case ambiguous
}

public struct FaceMatch: Equatable, Sendable {
  public let subjectID: String?
  public let score: Float?
  public let runnerUpScore: Float?
  public let decision: MatchDecision
}

public struct CosineFaceMatcher: Sendable {
  public let policy: MatchingPolicy

  public init(policy: MatchingPolicy) {
    self.policy = policy
  }

  public func verify(
    _ query: FaceEmbedding,
    against template: FaceTemplate,
    modelIdentifier: String
  ) throws -> FaceMatch {
    guard template.modelIdentifier == modelIdentifier else {
      throw FaceMatcherError.modelMismatch
    }
    let score = try query.cosineSimilarity(to: template.centroid())
    return FaceMatch(
      subjectID: score >= policy.threshold ? template.subjectID : nil,
      score: score,
      runnerUpScore: nil,
      decision: score >= policy.threshold ? .match : .noMatch
    )
  }

  public func identify(
    _ query: FaceEmbedding,
    among templates: [FaceTemplate],
    modelIdentifier: String
  ) throws -> FaceMatch {
    let candidates =
      try templates
      .filter { $0.modelIdentifier == modelIdentifier }
      .map { template in
        (template.subjectID, try query.cosineSimilarity(to: template.centroid()))
      }
      .sorted { $0.1 > $1.1 }

    guard let best = candidates.first else {
      return FaceMatch(
        subjectID: nil,
        score: nil,
        runnerUpScore: nil,
        decision: .noMatch
      )
    }

    let runnerUp = candidates.dropFirst().first?.1
    guard best.1 >= policy.threshold else {
      return FaceMatch(
        subjectID: nil,
        score: best.1,
        runnerUpScore: runnerUp,
        decision: .noMatch
      )
    }

    if let runnerUp, best.1 - runnerUp < policy.minimumMargin {
      return FaceMatch(
        subjectID: nil,
        score: best.1,
        runnerUpScore: runnerUp,
        decision: .ambiguous
      )
    }

    return FaceMatch(
      subjectID: best.0,
      score: best.1,
      runnerUpScore: runnerUp,
      decision: .match
    )
  }
}

public enum FaceMatcherError: Error, Equatable, Sendable {
  case modelMismatch
}
