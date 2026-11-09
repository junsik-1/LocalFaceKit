import CryptoKit
import Foundation
import Testing

@testable import LocalFaceKit

@Test func encryptedStoreRoundTripsAndDoesNotWritePlaintext() async throws {
  let directory = FileManager.default.temporaryDirectory
    .appendingPathComponent(UUID().uuidString, isDirectory: true)
  let fileURL = directory.appendingPathComponent("templates.enc")
  let store = EncryptedFileTemplateStore(
    fileURL: fileURL,
    key: SymmetricKey(size: .bits256)
  )
  let template = try FaceTemplate(
    subjectID: "private-subject",
    modelIdentifier: "test-v1",
    embeddings: [FaceEmbedding([1, 0, 0])]
  )

  try await store.save(template)
  let loaded = try await store.template(for: "private-subject")
  let ciphertext = try Data(contentsOf: fileURL)

  #expect(loaded == template)
  #expect(!String(decoding: ciphertext, as: UTF8.self).contains("private-subject"))

  try? FileManager.default.removeItem(at: directory)
}
