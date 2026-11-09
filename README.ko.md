# LocalFaceKit

[![CI](https://github.com/junsik-1/LocalFaceKit/actions/workflows/ci.yml/badge.svg)](https://github.com/junsik-1/LocalFaceKit/actions/workflows/ci.yml)
[![Swift 6](https://img.shields.io/badge/Swift-6-orange.svg)](https://swift.org)
[![License](https://img.shields.io/badge/License-Apache--2.0-blue.svg)](LICENSE)

Face ID가 없는 iPad의 일반 전면 RGB 카메라만으로 얼굴 감지와 인식을 구현하기 위한 프라이버시 우선 Swift 패키지입니다.

[English](README.md)

LocalFaceKit은 일반 전면 RGB 카메라를 사용하며 카메라 프레임, 모델, 생체 템플릿, 판정 결과를 앱 샌드박스 밖으로 전송하지 않습니다. 얼굴 감지, 랜드마크 추출, 임베딩, 1:1 검증 및 1:N 식별을 모두 로컬에서 수행합니다.

> [!WARNING]
> 이 프로젝트는 Face ID 하드웨어가 없는 iPad를 대상으로 하는 초기 단계 프로젝트입니다. 일반 RGB 카메라만 사용하며 고위험 인증의 유일한 수단으로 사용하면 안 됩니다.

## 현재 구현

- Vision 얼굴 사각형 및 랜드마크 분석
- 화면 방향을 반영하는 5점 유사 변환 얼굴 정렬
- 얼굴 수·크기·자세·조명·선명도 품질 필터
- Vision → 정렬 → Core ML 임베딩 통합 파이프라인
- Core ML 임베딩 모델 어댑터
- 임베딩 L2 정규화
- 1:1 검증과 1:N 식별
- 임계값과 후보 간 최소 마진 정책
- 복수 샘플 등록 템플릿
- AES-GCM 암호화 템플릿 저장소
- 기기 한정 Keychain 암호화 키
- Privacy Manifest와 자동화 테스트
- 최신 프레임 하나만 유지하는 일반 전면 RGB 카메라 스트림
- 안내, 진행률, 성공·재시도 상태를 제공하는 SwiftUI 얼굴 스캔 화면
- 런타임 네트워크 API를 거부하는 CI 검사

다음 단계는 시간축 합의, RGB 챌린지 기반 라이브니스 신호, iPad 샘플 앱과 실기기 벤치마크입니다.

저장소에는 사전 학습 얼굴 모델이나 실제 얼굴 데이터셋을 포함하지 않습니다. 모델 가중치는 별도의 재배포 권리와 데이터 출처 검토가 필요합니다.

## 요구 사항

- iPadOS 17 이상
- Swift 6 이상
- Xcode 16 이상
- 실시간 임베딩은 A12 Bionic 이상 권장
- 카메라와 성능 검증에는 일반 전면 카메라가 있는 실제 iPad 필요

## 설치

Xcode의 Swift Package Manager에서 다음 주소를 추가합니다.

```text
https://github.com/junsik-1/LocalFaceKit.git
```

호스트 앱의 `Info.plist`에 카메라 사용 목적을 추가합니다.

```xml
<key>NSCameraUsageDescription</key>
<string>얼굴 감지를 위해 카메라 프레임을 이 기기에서 처리합니다.</string>
```

패키지는 전면 광각 또는 초광각 RGB 카메라만 검색하며 TrueDepth 카메라를 선택하지 않습니다.

## 일반 전면 RGB 카메라

```swift
let camera = try RGBFrontCameraSource.make()
guard await RGBFrontCameraSource.requestAccess() else { return }

try await camera.start()
for await frame in camera.frames {
    let faces = try await analyzer.analyze(pixelBuffer: frame.pixelBuffer)
    // 프레임은 로컬에서 처리하고 보관하지 않습니다.
}
```

## 얼굴 스캔 UI

`FaceScanView`는 카메라 전체 화면, 둥근 얼굴 가이드, 움직이는 스캔 선, 진행 상태, 성공 체크 및 재시도 안내로 구성됩니다. 사용 흐름은 익숙하게 유지하되 Apple 시스템 Face ID 화면이나 Face ID 아이콘으로 오인되지 않도록 별도의 디자인과 문구를 사용합니다.

```swift
@State private var scanState: FaceScanState = .ready

FaceScanView(
    cameraSource: camera,
    state: $scanState,
    strings: .korean
)
```

인식 파이프라인에서 상태를 갱신합니다.

```swift
scanState = .positioning
scanState = .scanning(progress: 0.65)
scanState = .success
// 또는: .failure(message: "얼굴을 다시 맞춰주세요")
```

하단에는 “이 iPad 안에서만 처리됩니다”라는 프라이버시 안내가 항상 표시됩니다.

## 얼굴과 랜드마크 분석

```swift
import ImageIO
import LocalFaceKit

let analyzer = VisionFaceAnalyzer()
let faces = try await analyzer.analyze(
    pixelBuffer: cameraPixelBuffer,
    orientation: .leftMirrored,
    includeLandmarks: true
)
```

화면 미러링과 추론 이미지 방향을 분리하고 지원하는 모든 iPad 방향에서 좌표 변환을 테스트해야 합니다.

## 품질 판정·정렬·임베딩 실행

`FaceEmbeddingPipeline`은 카메라 프레임에서 부적합한 얼굴을 먼저 거부하고, 통과한 얼굴을 5점 기준으로 정렬한 뒤 로컬 Core ML 모델을 실행합니다. 미리보기 좌표 변환에 사용한 것과 같은 화면 방향을 전달해야 합니다.

```swift
import ImageIO
import LocalFaceKit

let embedder = try CoreMLFaceEmbedder(
    modelURL: compiledModelURL,
    modelIdentifier: "mobileface-112-v1"
)
let aligner = try FivePointFaceAligner(
    outputSize: embedder.inputImageSize.width
)
let pipeline = try FaceEmbeddingPipeline(
    qualityEvaluator: FaceQualityEvaluator(policy: .standard),
    aligner: aligner,
    embedder: embedder
)

let result = try await pipeline.process(
    pixelBuffer: cameraPixelBuffer,
    orientation: .leftMirrored
)
if case .accepted(let embedding, let quality) = result {
    print(embedding.values.count, quality.metrics)
}
```

기본 정렬기는 공개된 ArcFace 112×112 기준 좌표를 요청 크기로 확대해 정사각형 BGRA 버퍼를 만듭니다. 반드시 같은 정렬 규격으로 학습된 모델에만 사용해야 합니다. 모델을 불러올 때 이미지 입력 크기를 확인하며, 정렬기 출력 크기가 다르면 프레임 처리 전에 거부합니다.

`FaceQualityPolicy.standard`는 초기 엔지니어링 기본값이며 보안 임계값이 아닙니다. 지원할 iPad와 실제 대상 사용자군에서 자세·조명·선명도·얼굴 크기 제한을 검증하고 보정해야 합니다.

모델 규격과 라이선스 정책은 [Models/README.md](Models/README.md)를 참고하세요.

## 등록과 검증

```swift
let store = InMemoryTemplateStore()
let policy = try MatchingPolicy(threshold: calibratedThreshold)
let service = FaceRecognitionService(
    modelIdentifier: "mobileface-112-v1",
    store: store,
    matchingPolicy: policy
)

try await service.enroll(
    subjectID: "random-local-id",
    embeddings: enrollmentEmbeddings
)

let result = try await service.verify(
    queryEmbedding,
    claimedSubjectID: "random-local-id"
)
```

모든 모델에 통용되는 임계값은 없습니다. 실제 모델, 전처리, 대상 사용자군, 목표 오수락률에 맞춰 보정해야 합니다.

## 암호화 저장

```swift
let key = try KeychainKeyStore.loadOrCreateKey(
    service: "com.example.myapp.localface"
)
let store = EncryptedFileTemplateStore(
    fileURL: applicationSupportURL.appendingPathComponent("faces.enc"),
    key: key
)
```

호스트 앱은 사용자 동의, 보존 기간, 삭제 UI, 접근 통제를 제공해야 합니다. 자세한 내용은 [PRIVACY.md](PRIVACY.md), [SECURITY.md](SECURITY.md), [아키텍처](docs/ARCHITECTURE.md)를 참고하세요.

민감한 작업에는 얼굴 매칭 결과와 별개로 암호 등 다른 인증 요소를 사용하세요. RGB 기반 라이브니스만으로 사진이나 영상 재생 공격을 완전히 막을 수는 없습니다.

## 개발

```bash
swift test
```

실제 얼굴 사진, 운영 생체 템플릿, 라이선스가 불명확한 모델 가중치를 이슈나 Pull Request에 올리지 마세요.

## 라이선스

소스 코드는 [Apache License 2.0](LICENSE)으로 배포합니다. 모델, 데이터셋, 샘플 미디어는 각각의 별도 라이선스를 따릅니다.
