#if os(iOS)
  import SwiftUI

  /// Full-screen, Face ID-inspired interaction for the RGB-only local pipeline.
  /// This is application UI and never invokes Apple's Face ID APIs.
  public struct FaceScanView: View {
    private let cameraSource: RGBFrontCameraSource
    @Binding private var state: FaceScanState
    private let strings: FaceScanStrings
    private let tint: Color

    public init(
      cameraSource: RGBFrontCameraSource,
      state: Binding<FaceScanState>,
      strings: FaceScanStrings = .english,
      tint: Color = Color(red: 0.25, green: 0.82, blue: 0.96)
    ) {
      self.cameraSource = cameraSource
      self._state = state
      self.strings = strings
      self.tint = tint
    }

    public var body: some View {
      ZStack {
        RGBFaceCameraView(source: cameraSource)
          .ignoresSafeArea()

        LinearGradient(
          colors: [
            .black.opacity(0.68),
            .clear,
            .black.opacity(0.78),
          ],
          startPoint: .top,
          endPoint: .bottom
        )
        .ignoresSafeArea()

        VStack(spacing: 0) {
          Text(strings.title)
            .font(.largeTitle.bold())
            .foregroundStyle(.white)
            .padding(.top, 34)

          FaceScanOverlay(state: state, strings: strings, tint: tint)

          Label(strings.onDeviceOnly, systemImage: "lock.shield.fill")
            .font(.footnote.weight(.medium))
            .foregroundStyle(.white.opacity(0.82))
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(.black.opacity(0.34), in: Capsule())
            .padding(.bottom, 28)
        }
      }
      .background(.black)
    }
  }
#endif
