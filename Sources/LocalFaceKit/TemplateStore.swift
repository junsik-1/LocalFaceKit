import Foundation

public protocol FaceTemplateStoring: Sendable {
  func save(_ template: FaceTemplate) async throws
  func template(for subjectID: String) async throws -> FaceTemplate?
  func allTemplates() async throws -> [FaceTemplate]
  func remove(subjectID: String) async throws
  func removeAll() async throws
}

public actor InMemoryTemplateStore: FaceTemplateStoring {
  private var templates: [String: FaceTemplate] = [:]

  public init() {}

  public func save(_ template: FaceTemplate) {
    templates[template.subjectID] = template
  }

  public func template(for subjectID: String) -> FaceTemplate? {
    templates[subjectID]
  }

  public func allTemplates() -> [FaceTemplate] {
    templates.values.sorted { $0.subjectID < $1.subjectID }
  }

  public func remove(subjectID: String) {
    templates[subjectID] = nil
  }

  public func removeAll() {
    templates.removeAll(keepingCapacity: false)
  }
}
