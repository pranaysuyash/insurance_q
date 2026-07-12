# Reusable project tools

## `evaluate_local_document_models.py`

Compares direct PDF text extraction with locally hosted Ollama vision/OCR
models on a PDF fixture. It records timing, output size, and exact expected
token checks without persisting the policy text by default.

```bash
venv/bin/python tools/evaluate_local_document_models.py \
  tests/test_data/sample_insurance.pdf \
  --models deepseek-ocr:latest gemma3:4b qwen2.5vl:7b \
  --expected 'Insurance Policy' \
  --expected '#12345' \
  --output docs/review/evidence/local-model-eval/sample-policy.json
```

Use only synthetic fixtures or explicitly approved documents with
`--include-text`; reports otherwise retain no extracted document text.
