# Privacy policy for maintainers and integrators

LocalFaceKit is designed for fully on-device processing. The package contains no networking, telemetry, analytics, advertising, or runtime model-download code.

## Data handled

Depending on the host application, the pipeline may handle:

- transient RGB camera frames
- transient depth maps
- face rectangles and landmarks
- face embeddings and enrollment templates
- pseudonymous subject identifiers
- match scores and decisions

Face embeddings remain biometric data. They can enable cross-session linkage and may be sensitive even if reconstructing the source image is difficult.

## Package behavior

- Camera frames are inputs and are not persisted by this package.
- `InMemoryTemplateStore` loses all templates with the process.
- `EncryptedFileTemplateStore` persists only encrypted templates supplied by the host application.
- Persisted files are excluded from backup where the platform allows.
- `KeychainKeyStore` uses a device-local, when-unlocked Keychain item.

## Host application responsibilities

Applications must provide:

1. an accurate camera usage description;
2. informed consent before enrollment;
3. a clear explanation of purpose and retention;
4. deletion and re-enrollment controls;
5. a policy for failed or withdrawn consent;
6. local-law and sector-specific review;
7. a privacy policy when ARKit face tracking is used;
8. protection against screenshots, logs, crash reports, and debug exports leaking biometric data.

Use random local identifiers instead of names or email addresses. Do not store frames merely to debug production failures. Do not upload embeddings in support tickets.

## No network guarantee

The library itself has no network path. A host application can still add networking, so integrators who promise a fully offline product must audit the complete app and all dependencies, not only this package.
