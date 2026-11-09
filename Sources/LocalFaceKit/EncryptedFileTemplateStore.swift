import CryptoKit
import Foundation

/// AES-GCM encrypted persistence for face templates.
///
/// The caller owns key lifecycle. Use `KeychainKeyStore` in an application and
/// never persist the symmetric key next to the encrypted template file.
public actor EncryptedFileTemplateStore: FaceTemplateStoring {
  private struct Payload: Codable {
    let schemaVersion: Int
    var templates: [String: FaceTemplate]
  }

  private let fileURL: URL
  private let key: SymmetricKey
  private var payload: Payload?

  public init(fileURL: URL, key: SymmetricKey) {
    self.fileURL = fileURL
    self.key = key
  }

  public func save(_ template: FaceTemplate) throws {
    var current = try loadIfNeeded()
    current.templates[template.subjectID] = template
    try persist(current)
    payload = current
  }

  public func template(for subjectID: String) throws -> FaceTemplate? {
    try loadIfNeeded().templates[subjectID]
  }

  public func allTemplates() throws -> [FaceTemplate] {
    try loadIfNeeded().templates.values.sorted { $0.subjectID < $1.subjectID }
  }

  public func remove(subjectID: String) throws {
    var current = try loadIfNeeded()
    current.templates[subjectID] = nil
    try persist(current)
    payload = current
  }

  public func removeAll() throws {
    let empty = Payload(schemaVersion: 1, templates: [:])
    try persist(empty)
    payload = empty
  }

  private func loadIfNeeded() throws -> Payload {
    if let payload {
      return payload
    }
    guard FileManager.default.fileExists(atPath: fileURL.path) else {
      let empty = Payload(schemaVersion: 1, templates: [:])
      payload = empty
      return empty
    }

    do {
      let combined = try Data(contentsOf: fileURL)
      let sealedBox = try AES.GCM.SealedBox(combined: combined)
      let cleartext = try AES.GCM.open(sealedBox, using: key)
      let decoded = try Self.makeDecoder().decode(Payload.self, from: cleartext)
      guard decoded.schemaVersion == 1 else {
        throw EncryptedTemplateStoreError.unsupportedSchema(decoded.schemaVersion)
      }
      payload = decoded
      return decoded
    } catch let error as EncryptedTemplateStoreError {
      throw error
    } catch {
      throw EncryptedTemplateStoreError.cannotDecryptOrDecode
    }
  }

  private func persist(_ payload: Payload) throws {
    let directory = fileURL.deletingLastPathComponent()
    try FileManager.default.createDirectory(
      at: directory,
      withIntermediateDirectories: true
    )

    let cleartext = try Self.makeEncoder().encode(payload)
    let sealedBox = try AES.GCM.seal(cleartext, using: key)
    guard let combined = sealedBox.combined else {
      throw EncryptedTemplateStoreError.cannotCreateCombinedRepresentation
    }

    #if os(iOS)
      try combined.write(to: fileURL, options: [.atomic, .completeFileProtection])
    #else
      try combined.write(to: fileURL, options: .atomic)
    #endif

    var excludedURL = directory
    var resourceValues = URLResourceValues()
    resourceValues.isExcludedFromBackup = true
    try? excludedURL.setResourceValues(resourceValues)
  }

  private static func makeEncoder() -> JSONEncoder {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.sortedKeys]
    return encoder
  }

  private static func makeDecoder() -> JSONDecoder {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
  }
}

public enum EncryptedTemplateStoreError: Error, Equatable, Sendable {
  case cannotCreateCombinedRepresentation
  case cannotDecryptOrDecode
  case unsupportedSchema(Int)
}
