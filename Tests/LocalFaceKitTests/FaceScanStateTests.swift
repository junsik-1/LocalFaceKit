import XCTest

@testable import LocalFaceKit

final class FaceScanStateTests: XCTestCase {
  func testProgressIsClamped() {
    XCTAssertEqual(FaceScanState.scanning(progress: -0.5).normalizedProgress, 0)
    XCTAssertEqual(FaceScanState.scanning(progress: 0.4).normalizedProgress, 0.4)
    XCTAssertEqual(FaceScanState.scanning(progress: 1.5).normalizedProgress, 1)
    XCTAssertEqual(FaceScanState.success.normalizedProgress, 1)
  }

  func testOnlyScanningStateIsActive() {
    XCTAssertTrue(FaceScanState.scanning(progress: 0.2).isActivelyScanning)
    XCTAssertFalse(FaceScanState.positioning.isActivelyScanning)
    XCTAssertFalse(FaceScanState.success.isActivelyScanning)
  }
}
