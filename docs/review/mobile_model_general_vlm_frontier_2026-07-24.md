# General VLM OCR-capable models (frontier, not document-parser-first)

Source: sheet **General VLMs - OCR**

These models are not document-parser-first candidates; they are general multimodal VLMs with OCR capability and are **not** direct first-stage replacements without pipeline framing.

| Model | Provider/family | OCRBench v2 avg | Parsing score | Core note | Stage fit |
|---|---|---:|---:|---|---|
|KDL Frontier|KDL|68.1|92.2|General LMM; capable across OCR tasks but not a dedicated parser|Visual-stage fallback / second-stage only|
|NVIDIA Nemotron 3 Nano Omni|NVIDIA|65.8|93.3|General multimodal model; use through prompts and output validation|Visual-stage fallback / second-stage only|
|Qwen3.6-35B-A3B|Alibaba Qwen|65.5|91.5|General multimodal model, not a deterministic document pipeline|Visual-stage fallback / second-stage only|
|Qwen3.5-35B-A3B|Alibaba Qwen|65.3|90.5|General multimodal model; prompt format materially affects OCR output|Visual-stage fallback / second-stage only|
|Gemini 3 Pro Preview|Google|63.4|93.9|Frontier general model with strong parsing; version and API behaviour change|Visual-stage fallback / second-stage only|
|Seed1.6-Vision|ByteDance Seed|62.2|89|General vision model; not ByteDance Dolphin specialist parser|Visual-stage fallback / second-stage only|
|TeleMM-2.0|TeleAI|61.8|92.8|General LMM evaluated for OCR|Visual-stage fallback / second-stage only|
|Qwen3-Omni-30B-A3B-Instruct|Alibaba Qwen|61.3|93.5|Omni/general model, useful for reasoning and extraction but not specialized parsing|Visual-stage fallback / second-stage only|
|Nemotron Nano V2 VL|NVIDIA|61.2|92|General compact VLM with benchmarked OCR ability|Visual-stage fallback / second-stage only|
|Gemini 2.5 Pro|Google|59.3|93.7|General multimodal model; strong parsing but API/prompt dependent|Visual-stage fallback / second-stage only|
|GLM-4.6V-Flash|Z.ai|59|88.5|General GLM vision model; distinct from specialist GLM-OCR|Visual-stage fallback / second-stage only|
|Qwen3.5-9B|Alibaba Qwen|58.7|91.1|General compact VLM with OCR evidence|Visual-stage fallback / second-stage only|
|SenseNova-U1|SenseTime|58.2|80.5|General multimodal model|Research only|
|Llama-3.1-Nemotron-Nano-VL-8B-V1|NVIDIA / Meta Llama|56.4|88.2|General VLM; coordinates and structure require prompting|Visual-stage fallback / second-stage only|
|GPT-5 (2025-08-07)|OpenAI|55.5|90.1|General model; structured extraction possible but not a fixed parser|Visual-stage fallback / second-stage only|
|Ovis2.5-8B|Ovis|54.1|89.8|General VLM benchmarked on OCR tasks|Visual-stage fallback / second-stage only|
|Gemma 4 12B|Google|51.8|81.8|General VLM; OCR is one capability among many|Research only|
|Gemini 1.5 Pro|Google|51.6|89.5|General multimodal model; native long-context document handling|Visual-stage fallback / second-stage only|
|LLaVA-OneVision 2 8B Instruct|LLaVA|47.6|87.8|General open VLM; not document-specialized|Research only|
|MiniCPM-V-4.6|OpenBMB|40.4|78.5|Compact general VLM; useful for edge extraction but lower benchmark breadth|Research only|
|GPT-5.2|OpenAI|50.5|90.3|General model; prompt and API-version dependent|Visual-stage fallback / second-stage only|
|Claude Opus 4.6|Anthropic|48.4|92|General model with strong document parsing but no deterministic parser contract|Visual-stage fallback / second-stage only|
|MiniCPM-V-2.6|OpenBMB|47.7|76|General compact VLM|Research only|
|MiniCPM-o-2.6|OpenBMB|47.7|68|Omni/general model rather than specialist parser|Research only|
|Claude Sonnet 4|Anthropic|47.3|76|General multimodal model|Research only|
|GPT-4o|OpenAI|45.7|76|General multimodal model; useful OCR baseline but weaker structural guarantees|Research only|
|Qwen2-VL-7B|Alibaba Qwen|44.7|80|General VLM; adapted bounding-box prompts can improve text spotting|Research only|
|LLaVA-OneVision-1.5-8B-Instruct|LLaVA|43.8|76|General open VLM|Research only|
|CogVLM-chat|Z.ai / THUDM|12.8|20|Included as a historical general-VLM OCR baseline|Research only|
|VILA1.5-8B|NVIDIA / MIT|11|16|General vision-language baseline, not document-specialized|Research only|
|Yi-VL-6B|01.AI|10.4|10|General vision-language baseline|Research only|
|LLaVA-NeXT-8B|LLaVA|9.2|20|General vision-language baseline|Research only|
|Janus-1.3B|DeepSeek|7.5|14|General unified vision model; distinct from DeepSeek-OCR|Research only|