# Embedding model contract

This directory intentionally contains no face-recognition weights.

Production applications must bundle an authorized model in the signed app. `CoreMLFaceEmbedder` rejects non-file URLs, and LocalFaceKit contains no model downloader.

## Recommended contract

| Property | Initial recommendation |
| --- | --- |
| Core ML format | ML Program in `.mlpackage` |
| Input | image feature named `image` |
| Input size | 112×112 RGB |
| Alignment | documented five-point similarity transform |
| Output | `MLMultiArray` named `embedding` |
| Output dimension | 128 or 512 |
| Runtime precision | FP16 baseline |
| Output processing | L2 normalization |

`CoreMLFaceEmbedder` supports custom input and output names, reads the model's declared image dimensions, and rejects pixel buffers with a different size. `FivePointFaceAligner` implements the published ArcFace five-point reference geometry and emits BGRA. Use it only when that geometry and image representation match the model's training contract; otherwise supply preprocessing that exactly matches the authorized model.

## Required model metadata

Before a model is distributed, document:

- model identifier and semantic version
- architecture and training objective
- training-data provenance and consent basis
- checkpoint and dataset licenses
- expected input alignment and color order
- output dimension
- conversion command and `coremltools` version
- quantization settings
- accuracy before and after conversion
- calibrated verification and identification thresholds
- evaluation hardware and subgroup metrics
- SHA-256 checksum of the distributed artifact

Changing preprocessing is a model compatibility change. Existing templates must not be silently compared with embeddings from a different model contract.

## Licensing rule

An open-source implementation license does not automatically grant permission to redistribute its pretrained checkpoint or underlying dataset. Do not commit a weight file until the project has documented redistribution and intended-use rights.

In particular, InsightFace code and published model packages have different terms; its open model packages are described as non-commercial research only. Users can build a local adapter for a model they are authorized to use, but those weights must not be copied into this repository without a separate review.

## Conversion

Use Apple's `coremltools` and prefer direct conversion from PyTorch rather than adding another runtime to the iPad application. Conversion scripts should pin dependencies and compare source-model and Core ML embeddings on a licensed test set with numeric tolerances.

Start with FP16. Evaluate compressed weights only after measuring recognition accuracy and latency on physical iPads.
