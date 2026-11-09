# Security policy

## Reporting a vulnerability

Do not open a public issue for vulnerabilities involving template disclosure, key handling, camera privacy, model tampering, or authentication bypass.

Until a dedicated security contact is configured, use GitHub's private vulnerability reporting feature for this repository. Include the affected revision, impact, reproduction steps, and any suggested mitigation. Do not attach real biometric data.

## Scope and guarantees

LocalFaceKit targets iPads without Face ID and uses only their ordinary front RGB camera. Similarity matching and optional RGB liveness heuristics do not provide a Secure Enclave-backed authentication guarantee.

For high-value actions:

- require a passcode or another independent factor;
- rate-limit failures and provide a recovery path;
- calibrate thresholds from representative evaluation data;
- detect model and template version mismatches;
- treat rooted or instrumented devices as outside the trust boundary where appropriate.

## Key and template handling

- Never store the encryption key beside the encrypted file.
- Prefer `ThisDeviceOnly` Keychain accessibility.
- Consider `SecAccessControl` with user presence for personal-device apps.
- Clear templates when the user withdraws consent.
- Never log embeddings, keys, or decrypted payloads.
- Validate model integrity if applications load models outside the signed app bundle.

## Presentation attacks

RGB blink or head-turn checks are signals, not proofs. Printed photos, replayed videos, screen reflections, masks, and camera-specific attacks must be included in threat modeling and testing.
