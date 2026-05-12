# Llama Server Docker Container

This project provides a dedicated Docker container for running the Llama.cpp server on CUDA enabled devices.
This specific setup is intended for usage as Local LLM model for agentic coding.
Although other uses and webUI chat is also possible depending on the model, the model choices and json settings might need tweaking.

## Before you start

Before starting it is advised to either do your own research, or read the (AI generated) note on the pros and cons of using a local LLM for coding vs an online AI : [local_vs_online.md](./local_vs_online.md).

## Architecture

Based on the `nvidia/cuda:13.1.2-runtime-ubuntu24.04` image; edit the base image in `.Dockerfile` to suit your own cuda version.
For GGUF LLM Models, CUDA 13.2 is not advised yet.
Uses GPU acceleration (CUDA) for optimal performance. Not tested on non-NVIDIA / CUDA setups.

## Features

- **Dedicated Llama Server**: Runs only the Llama.cpp server with GPU acceleration
- **Configuration Management**: Supports multiple Llama configurations
- **Model Management**: Ready to work with GGUF model files
- **Network Compatibility**: Accessible via localhost on port 8001
- **Optional Chat via WebUI**: Optionally Enable WebUI in compose to allow chat via webbrowser

## Directory Structure

```bash
llama-docker/
├── Dockerfile              # Docker image definition
├── compose.yml             # Docker Compose configuration
├── entrypoint.sh           # Container startup script
├── config/                 # Llama configurations
│   ├── llama_default.json  # Default Llama configuration
│   └── llama_ ... .json    # Other Llama configuration files
├── LLM_Model               # Storage location of LLM Model (not included due to size)
└── __backup/               # Template files for configuration
```

## Integration

This Llama server can be used by other services or tools that need access to a local LLM inference engine via the Claude-compatible API endpoint at `http://localhost:8001`.
If enabled, you can also chose to use normal webchat via your browser at <http://localhost:8001>
When the Claude installation is containerized, add the `llama-network` network to that compose file and then you can set the  

## Configuration

- The Llama server configuration is managed in the compose file
- The Llama model configuration is managed in  `config/llama_default.json` and can be customized for different models and/or parameters.

## Connecting to a local Claude install

set the environment variables:

- `ANTHROPIC_BASE_URL` = `http://localhost:8001`
- `ANTHROPIC_API_KEY` = `sk-dummy-key`

```bash
export ANTHROPIC_BASE_URL=http://localhost:8001 >> /etc/bash.bashrc
export ANTHROPIC_API_KEY=sk-dummy-key >> /etc/bash.bashrc
```

## Connecting to a Containerized Claude

- Use my [local_claude_in_devcontainer](https://github.com/ImagineerNL/local_claude_in_devcontainer) fork of the original [claude_in_devcontainer Michael Hannecke](https://github.com/michaelhannecke/claude_in_devcontainer)
- Edit the container's `compose.yml` and add/set the following:

## Cherry-picking models

- Browse huggingface for llama compatible models. Set your hardware in [huggingface settings](https://huggingface.co/settings/local-apps) to see an estimation of capabilities.
- The [Unsloth Model Catalog](https://unsloth.ai/docs/get-started/unsloth-model-catalog) is also a great place to start as it is well documented.
- Pick the size that has a green check on your hardware, e.g. often Q4_K_M for RTX4090
- Place them in their repo/model directory, e.g. `./LLM_Model/unsloth/Qwen3-Coder-30B-A3B-Instruct-GGUF/Qwen3-Coder-30B-A3B-Instruct-UD-Q4_K_XL.gguf`
- Edit the `config/llama/llama_default.json` to reflect the newly downloaded model or copy and create a new one to reference in the compose file.
- Most of the models below already have an example config; you just need to download the files.

### Gemma 4

- 26B <https://huggingface.co/unsloth/gemma-4-26B-A4B-it-GGUF>
- RTX4090 compatible: `gemma-4-26B-A4B-it-UD-Q8_K_XL.gguf`
- 4B <https://huggingface.co/unsloth/gemma-4-E4B-it-GGUF>
- RTX4090 compatible: `gemma-4-E4B-it-UD-Q8_K_XL.gguf`
- Include the mmproj file Include the mmproj file if you want to process images, else keep empty: `mmproj-F16.gguf`
- Unsloth documentation: <https://unsloth.ai/docs/models/gemma-4>
- Suggested settings: `temperature=1.0, top_p=0.95, top_k=64`.
- Start with a context length of 32,768 for responsiveness, then increase. Gemma 4's max context is 128K for E2B / E4B and 256K for 26B A4B / 31B.
- Compared to older Gemma chat templates, Gemma 4 uses the standard system, assistant, and user roles and adds explicit thinking control. To enable thinking add the token `<|think|>` at the start of the system prompt.

### QWEN3-Coder

- <https://huggingface.co/unsloth/Qwen3-Coder-30B-A3B-Instruct-GGUF>
- RTX4090 compatible: `Qwen3-Coder-30B-A3B-Instruct-UD-Q4_K_XL.gguf`
- Unsloth documentation: <https://unsloth.ai/docs/models/tutorials/qwen3-coder-how-to-run-locally>
- Suggested settings: `temperature=0.7, top_p=0.8, top_k=20, min_p=0.01, repetition_penalty=1.05`.
- If you encounter out-of-memory (OOM) issues, consider reducing the context length to a shorter value, such as 32,768.
- Given that this is a non thinking model, there is no need to set `thinking=false` and the model does not generate `<think> </think>` blocks.

### QWEN3.5

- <https://huggingface.co/unsloth/Qwen3.5-35B-A3B-GGUF/>
- RTX4090 compatible: `Qwen3.5-35B-A3B-UD-Q4_K_XL.gguf`
- Unsloth documentation: <https://unsloth.ai/docs/basics/claude-code#claude-code-tutorial>
- Suggested settings: `temperature=0.6, top_p=0.95, top_k=20, min_p=0.0`
- Qwen3.6 models operate in thinking mode by default, generating thinking content signified by `<think>\n...</think>\n\n`  before producing the final responses. To disable thinking content and obtain direct response while keeping a lower vram usage, specify `"enable_thinking" ": false` in the json.

### QWEN3.6

- <https://huggingface.co/unsloth/Qwen3.6-35B-A3B-GGUF>
- RTX4090 compatible: `Qwen3.6-35B-A3B-UD-Q4_K_XL.gguf`
- Include the mmproj file if you want to process images, else keep empty: `mmproj-F16.gguf`
- Unsloth documentation: <https://unsloth.ai/docs/models/qwen3.6>
- Suggested settings for coding: `temperature=0.6, top_p=0.95, top_k=20, min_p=0.0, presence_penalty=0.0, repetition_penalty=1.0`
- Qwen3.6 models operate in thinking mode by default, generating thinking content signified by `<think>\n...</think>\n\n` before producing the final responses. To disable thinking content and obtain direct response while keeping a lower vram usage, specify `"enable_thinking" ": false` in the json.

## TROUBLESHOOTING

If your docker crashed, The server likely ran out of GPU VRAM (OOM)

### Try tweaking model.json settings

- reducing the context size (ctx_size)"
- offloading fewer layers to gpu (n_gpu_layers)"
- using a smaller, more quantized model or version"
- using a different model"

### Or in compose.yml

- Force fp16 calculations (CUDA_FORCE_FP16)
- Enabling shared VRAM+RAM (CUDA_SHARED_MEMORY). This will degrade performance, but stops OOM crashes if you have enough RAM

### If it is stupid but it works, it is not stupid

Post your startup or crash log into any ai web chat ()

## LICENSE

This project is licensed under GPL3 license.
All software referenced in this project is licensed under its own licens