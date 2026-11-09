import Foundation
import SwiftUI

/// A familiar biometric scanning presentation with original LocalFaceKit visuals.
/// It intentionally avoids Apple's Face ID icon and system-authentication wording.
public struct FaceScanOverlay: View {
  private let state: FaceScanState
  private let strings: FaceScanStrings
  private let tint: Color

  public init(
    state: FaceScanState,
    strings: FaceScanStrings = .english,
    tint: Color = Color(red: 0.25, green: 0.82, blue: 0.96)
  ) {
    self.state = state
    self.strings = strings
    self.tint = tint
  }

  public var body: some View {
    GeometryReader { proxy in
      let frameSize = min(min(proxy.size.width * 0.72, proxy.size.height * 0.58), 360)

      VStack(spacing: 28) {
        Spacer(minLength: 0)
        ZStack {
          RoundedRectangle(cornerRadius: frameSize * 0.18, style: .continuous)
            .stroke(.white.opacity(0.72), lineWidth: 2)

          RoundedRectangle(cornerRadius: frameSize * 0.18, style: .continuous)
            .trim(from: 0, to: max(state.normalizedProgress, 0.001))
            .stroke(
              state == .success ? Color.green : tint,
              style: StrokeStyle(lineWidth: 5, lineCap: .round)
            )
            .rotationEffect(.degrees(-90))
            .shadow(color: activeColor.opacity(0.7), radius: 8)

          if state.isActivelyScanning {
            AnimatedScanLine(tint: tint)
              .clipShape(
                RoundedRectangle(cornerRadius: frameSize * 0.18, style: .continuous)
              )
              .padding(8)
          }

          statusSymbol
        }
        .frame(width: frameSize, height: frameSize)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(statusMessage)
        .accessibilityValue(accessibilityProgress)

        Text(statusMessage)
          .font(.headline)
          .multilineTextAlignment(.center)
          .foregroundStyle(.white)
          .padding(.horizontal, 28)
          .animation(.easeInOut(duration: 0.2), value: state)

        Spacer(minLength: 0)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }

  private var activeColor: Color {
    switch state {
    case .success:
      return .green
    case .failure:
      return .orange
    default:
      return tint
    }
  }

  @ViewBuilder
  private var statusSymbol: some View {
    switch state {
    case .ready:
      Image(systemName: "person.crop.circle")
        .font(.system(size: 42, weight: .light))
        .foregroundStyle(.white.opacity(0.82))
    case .positioning:
      Image(systemName: "viewfinder")
        .font(.system(size: 40, weight: .light))
        .foregroundStyle(tint)
    case .scanning:
      EmptyView()
    case .success:
      Image(systemName: "checkmark.circle.fill")
        .font(.system(size: 62, weight: .semibold))
        .foregroundStyle(.green)
        .transition(.scale.combined(with: .opacity))
    case .failure:
      Image(systemName: "arrow.clockwise.circle.fill")
        .font(.system(size: 54, weight: .semibold))
        .foregroundStyle(.orange)
    }
  }

  private var statusMessage: String {
    switch state {
    case .ready:
      return strings.ready
    case .positioning:
      return strings.positioning
    case .scanning:
      return strings.scanning
    case .success:
      return strings.success
    case .failure(let message):
      return message
    }
  }

  private var accessibilityProgress: String {
    guard state.isActivelyScanning else { return "" }
    return "\(Int(state.normalizedProgress * 100))%"
  }
}

private struct AnimatedScanLine: View {
  let tint: Color

  var body: some View {
    TimelineView(.animation(minimumInterval: 1 / 60)) { context in
      GeometryReader { proxy in
        let elapsed = context.date.timeIntervalSinceReferenceDate
        let position = CGFloat((sin(elapsed * .pi / 0.9) + 1) / 2)

        Rectangle()
          .fill(
            LinearGradient(
              colors: [.clear, tint.opacity(0.95), .clear],
              startPoint: .leading,
              endPoint: .trailing
            )
          )
          .frame(height: 3)
          .shadow(color: tint, radius: 8)
          .offset(y: position * max(proxy.size.height - 3, 0))
      }
    }
  }
}
