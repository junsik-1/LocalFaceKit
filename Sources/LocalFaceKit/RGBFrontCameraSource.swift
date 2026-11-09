@preconcurrency import AVFoundation
import CoreVideo
import Foundation

/// A read-only RGB camera frame retained for the lifetime of this value.
public struct RGBFrame: @unchecked Sendable {
  public let pixelBuffer: CVPixelBuffer
  public let timestamp: CMTime
}

/// Streams frames from an ordinary front RGB camera.
///
/// The discovery list deliberately excludes `.builtInTrueDepthCamera`, so the
/// same RGB-only path is used on iPads that do not have Face ID hardware.
public final class RGBFrontCameraSource: NSObject, @unchecked Sendable {
  public let frames: AsyncStream<RGBFrame>

  private let continuation: AsyncStream<RGBFrame>.Continuation
  private let session = AVCaptureSession()
  private let sessionQueue = DispatchQueue(label: "LocalFaceKit.RGBFrontCamera")
  private let output = AVCaptureVideoDataOutput()

  private override init() {
    let stream = AsyncStream.makeStream(
      of: RGBFrame.self,
      bufferingPolicy: .bufferingNewest(1)
    )
    self.frames = stream.stream
    self.continuation = stream.continuation
    super.init()
  }

  public static func make() throws -> RGBFrontCameraSource {
    let source = RGBFrontCameraSource()
    try source.configureSession()
    return source
  }

  deinit {
    continuation.finish()
    if session.isRunning {
      session.stopRunning()
    }
  }

  public static var authorizationStatus: AVAuthorizationStatus {
    AVCaptureDevice.authorizationStatus(for: .video)
  }

  public static func requestAccess() async -> Bool {
    await AVCaptureDevice.requestAccess(for: .video)
  }

  public func start() async throws {
    guard Self.authorizationStatus == .authorized else {
      throw RGBFrontCameraError.cameraPermissionRequired
    }
    await withCheckedContinuation { continuation in
      sessionQueue.async { [self] in
        if !session.isRunning {
          session.startRunning()
        }
        continuation.resume()
      }
    }
  }

  public func stop() async {
    await withCheckedContinuation { continuation in
      sessionQueue.async { [self] in
        if session.isRunning {
          session.stopRunning()
        }
        continuation.resume()
      }
    }
  }

  private func configureSession() throws {
    #if os(iOS)
      let deviceTypes: [AVCaptureDevice.DeviceType] = [
        .builtInWideAngleCamera, .builtInUltraWideCamera,
      ]
    #else
      let deviceTypes: [AVCaptureDevice.DeviceType] = [.builtInWideAngleCamera]
    #endif
    let discovery = AVCaptureDevice.DiscoverySession(
      deviceTypes: deviceTypes,
      mediaType: .video,
      position: .front
    )
    guard let device = discovery.devices.first else {
      throw RGBFrontCameraError.frontRGBCameraUnavailable
    }

    let input = try AVCaptureDeviceInput(device: device)
    session.beginConfiguration()
    defer { session.commitConfiguration() }

    if session.canSetSessionPreset(.hd1280x720) {
      session.sessionPreset = .hd1280x720
    }
    guard session.canAddInput(input) else {
      throw RGBFrontCameraError.cannotAddCameraInput
    }
    session.addInput(input)

    output.alwaysDiscardsLateVideoFrames = true
    output.videoSettings = [
      kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
    ]
    output.setSampleBufferDelegate(self, queue: sessionQueue)
    guard session.canAddOutput(output) else {
      throw RGBFrontCameraError.cannotAddVideoOutput
    }
    session.addOutput(output)
  }
}

extension RGBFrontCameraSource: AVCaptureVideoDataOutputSampleBufferDelegate {
  public func captureOutput(
    _ output: AVCaptureOutput,
    didOutput sampleBuffer: CMSampleBuffer,
    from connection: AVCaptureConnection
  ) {
    guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
      return
    }
    continuation.yield(
      RGBFrame(
        pixelBuffer: pixelBuffer,
        timestamp: CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
      )
    )
  }
}

public enum RGBFrontCameraError: Error, Equatable, Sendable {
  case cameraPermissionRequired
  case frontRGBCameraUnavailable
  case cannotAddCameraInput
  case cannotAddVideoOutput
}
