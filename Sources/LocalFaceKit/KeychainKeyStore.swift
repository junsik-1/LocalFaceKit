import CryptoKit
import Foundation
import Security

/// Creates and retrieves a device-local 256-bit key for encrypted templates.
public enum KeychainKeyStore {
  public static func loadOrCreateKey(
    service: String,
    account: String = "face-template-encryption-key"
  ) throws -> SymmetricKey {
    let lookup: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne,
    ]

    var item: CFTypeRef?
    let status = SecItemCopyMatching(lookup as CFDictionary, &item)
    if status == errSecSuccess, let data = item as? Data {
      return SymmetricKey(data: data)
    }
    guard status == errSecItemNotFound else {
      throw KeychainKeyStoreError.unexpectedStatus(status)
    }

    let key = SymmetricKey(size: .bits256)
    let keyData = key.withUnsafeBytes { Data($0) }
    let insertion: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
      kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
      kSecValueData as String: keyData,
    ]
    let addStatus = SecItemAdd(insertion as CFDictionary, nil)
    guard addStatus == errSecSuccess else {
      throw KeychainKeyStoreError.unexpectedStatus(addStatus)
    }
    return key
  }
}

public enum KeychainKeyStoreError: Error, Equatable, Sendable {
  case unexpectedStatus(OSStatus)
}
