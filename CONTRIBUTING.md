# Contributing

Thank you for helping make private, on-device face analysis safer and easier to audit.

## Before opening a pull request

1. Discuss substantial API or architecture changes in an issue.
2. Keep runtime behavior fully on-device.
3. Add or update tests.
4. Run `swift test`.
5. Document privacy, performance, and compatibility implications.
6. Confirm that every added asset, model, and fixture has a redistribution license.

Never commit real face images, production templates, encryption keys, or model weights with ambiguous rights. Use synthetic or explicitly licensed fixtures and record their provenance.

## API principles

- Prefer small protocols and value types.
- Keep camera, model, storage, and policy components replaceable.
- Make model identifiers and compatibility checks explicit.
- Avoid universal thresholds or undocumented confidence transformations.
- Preserve Swift 6 strict-concurrency safety.

## Commit and review expectations

Use focused commits and explain why a change is safe. Recognition changes should report accuracy methodology; performance changes should identify the tested device and OS. Security-sensitive changes may require private review before disclosure.
