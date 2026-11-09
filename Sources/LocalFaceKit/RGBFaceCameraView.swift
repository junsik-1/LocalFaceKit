#if os(iOS)
  @preconcurrency import AVFoundation
  import SwiftUI
  import UIKit

  /// SwiftUI preview backed by the RGB-only capture session.
  public struct RGBFaceCameraView: UIViewRepresentable {
    private let source: RGBFrontCameraSource

    public init(source: RGBFrontCameraSource) {
      self.source = source
    }

    public func makeUIView(context: Context) -> RGBPreviewView {
      let view = RGBPreviewView()
      view.previewLayer.session = source.previewSession
      view.previewLayer.videoGravity = .resizeAspectFill
      return view
    }

    public func updateUIView(_ uiView: RGBPreviewView, context: Context) {
      uiView.updateRotation()
    }
  }

  public final class RGBPreviewView: UIView {
    public override class var layerClass: AnyClass {
      AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
      layer as! AVCaptureVideoPreviewLayer
    }

    public override func layoutSubviews() {
      super.layoutSubviews()
      updateRotation()
    }

    func updateRotation() {
      guard
        let orientation = window?.windowScene?.interfaceOrientation,
        let connection = previewLayer.connection
      else { return }

      let angle: CGFloat
      switch orientation {
      case .portrait:
        angle = 90
      case .portraitUpsideDown:
        angle = 270
      case .landscapeLeft:
        angle = 0
      case .landscapeRight:
        angle = 180
      default:
        return
      }

      if connection.isVideoRotationAngleSupported(angle) {
        connection.videoRotationAngle = angle
      }
    }
  }
#endif
