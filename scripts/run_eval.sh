#!/usr/bin/env bash
set -e

echo "Running CoverWise RAG evaluation..."
python -m src.eval.ragas_eval \
    --fail-under-accuracy 0.75 \
    --fail-under-faithfulness 0.80

echo "Evaluation passed!"
