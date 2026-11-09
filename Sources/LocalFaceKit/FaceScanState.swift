import Foundation

public enum FaceScanState: Equatable, Sendable {
  case ready
  case positioning
  case scanning(progress: Double)
  case success
  case failure(message: String)

  public var normalizedProgress: Double {
    guard case .scanning(let progress) = self else {
      return self == .success ? 1 : 0
    }
    return min(max(progress, 0), 1)
  }

  public var isActivelyScanning: Bool {
    if case .scanning = self {
      return true
    }
    return false
  }
}

public struct FaceScanStrings: Equatable, Sendable {
  public let title: String
  public let ready: String
  public let positioning: String
  public let scanning: String
  public let success: String
  public let onDeviceOnly: String

  public init(
    title: String,
    ready: String,
    positioning: String,
    scanning: String,
    success: String,
    onDeviceOnly: String
  ) {
    self.title = title
    self.ready = ready
    self.positioning = positioning
    self.scanning = scanning
    self.success = success
    self.onDeviceOnly = onDeviceOnly
  }

  public static let english = FaceScanStrings(
    title: "Verify your face",
    ready: "Position your face inside the frame",
    positioning: "Move closer and look straight ahead",
    scanning: "Keep still while your face is checked",
    success: "Face verified",
    onDeviceOnly: "Processed only on this iPad"
  )

  public static let korean = FaceScanStrings(
    title: "얼굴 확인",
    ready: "얼굴을 프레임 안에 맞춰주세요",
    positioning: "조금 더 가까이에서 정면을 봐주세요",
    scanning: "확인이 끝날 때까지 잠시 멈춰주세요",
    success: "얼굴 확인이 완료되었습니다",
    onDeviceOnly: "이 iPad 안에서만 처리됩니다"
  )
}
