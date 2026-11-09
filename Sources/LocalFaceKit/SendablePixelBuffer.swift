import CoreVideo

/// The pipeline treats camera and aligned buffers as immutable while they
/// cross actor boundaries. Core Video does not currently declare this type
/// Sendable, so the unchecked wrapper documents that ownership contract.
struct SendablePixelBuffer: @unchecked Sendable {
  let value: CVPixelBuffer
}
