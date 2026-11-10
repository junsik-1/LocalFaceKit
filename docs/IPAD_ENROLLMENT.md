# iPad enrollment integration

The package now includes `FaceEnrollmentSession`: a bounded collection of quality-approved embeddings, capture-time spacing, progress, and cancellation/reset. It connects the existing embedding pipeline to the existing enrollment service. It is not yet a standalone iPad app.

## Host app prerequisites

1. Create an iPadOS 17+ SwiftUI app in Xcode and add this package.
2. Add `NSCameraUsageDescription` to the app's Info.plist.
3. Supply a licensed, compatible compiled Core ML embedding model as described in [Models](../Models/README.md). No model weights ship here.
4. Build a `FaceEmbeddingPipeline` and a `FaceRecognitionService` using the same model identifier. Use `EncryptedFileTemplateStore` with a Keychain key for persistence.
5. Obtain enrollment consent in the host UI before starting the camera. Provide cancel and template deletion controls.

## Camera loop

Run one frame consumer at a time. The host owns camera lifetime and UI state; update SwiftUI state on the main actor. Pass an image orientation that matches the actual capture buffer and current device orientation. Preview mirroring alone does not determine buffer orientation.

```swift
import CoreMedia
import ImageIO
import LocalFaceKit

// Assumes camera, pipeline, service, subjectID and currentBufferOrientation
// were configured by the host. Obtain consent before entering this flow.
var enrollment = try FaceEnrollmentSession(
    modelIdentifier: pipeline.modelIdentifier,
    requiredSampleCount: 5,
    minimumSampleInterval: 0.4
)

guard await RGBFrontCameraSource.requestAccess() else {
    // Show a permission explanation and a Settings action in the host app.
    return
}

do {
    try await camera.start()
    for await frame in camera.frames {
        try Task.checkCancellation()
        let result = try await pipeline.process(
            pixelBuffer: frame.pixelBuffer,
            orientation: currentBufferOrientation
        )
        guard let embedding = result.embedding else {
            // Display quality guidance; rejected frames do not advance progress.
            continue
        }
        try enrollment.append(
            embedding,
            modelIdentifier: pipeline.modelIdentifier,
            timestamp: CMTimeGetSeconds(frame.timestamp)
        )
        // On the main actor: scanState = .scanning(progress: enrollment.progress)
        if enrollment.isComplete {
            let template = try enrollment.template(subjectID: subjectID)
            try await service.enroll(
                subjectID: template.subjectID,
                embeddings: template.embeddings
            )
            // Report success only after persistence succeeds.
            break
        }
    }
    enrollment.reset()
    await camera.stop()
} catch {
    enrollment.reset()
    await camera.stop()
    throw error
}
```

On cancel, cancel the consumer task and stop the camera explicitly so a task waiting for its next frame can exit. Also stop capture when the app enters the background. On restart, create a fresh session or call `reset()` before consuming a new capture timeline. Do not share one mutable enrollment session between tasks.

The collector checks model identity, dimensions, finite nonnegative timestamps, and ordering relative to the last accepted sample. It collects 2–30 samples and ignores frames that are too close to the last accepted sample. Default spacing is an initial development setting, not a calibrated security policy. Time spacing does not prove that samples depict one person, and does not establish liveness. The host must keep one consenting subject in the flow; identity consistency and challenge-response remain future work.

## Validation still required

- Run Swift tests and iOS Simulator build through repository CI.
- On a physical iPad, test camera permissions, cancellation, background/foreground transitions, and portrait/landscape capture orientation.
- With the chosen model, calibrate matching thresholds and measure false matches, false rejections, latency, and behavior across lighting and pose.
- Verify enrollment, app restart, verification, and deletion with the encrypted store.

No physical iPad or Xcode execution has been performed from the Windows development workspace.
