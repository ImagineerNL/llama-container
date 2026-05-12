#!/bin/bash

# Exit on pipefail
set -eo pipefail

# Ensure config directories exist
mkdir -p /config

# Use the default config files
LLAMA_CONFIG_FILE="/config/llama_default.json"

# If a config file is specified via environment variable, use that instead
if [ ! -z "$LLAMA_CONFIG_FILE_PATH" ]; then
    LLAMA_CONFIG_FILE="$LLAMA_CONFIG_FILE_PATH"
fi

# Check if the config files exists
if [ ! -f "$LLAMA_CONFIG_FILE" ]; then
    echo "INFO: No Llama config file present, copying default from zz_templates"
    cp /__backup/config/llama_default.json /config/llama_default.json
    LLAMA_CONFIG_FILE="/config/llama_default.json"
else
    echo "INFO: Using Llama.cpp config at $LLAMA_CONFIG_FILE."
fi

# Parse config file if it exists to override environment variables
if [ -f "$LLAMA_CONFIG_FILE" ]; then
    echo "INFO: Loading configuration from $LLAMA_CONFIG_FILE"

    # Read values from the config file if available
    if command -v jq >/dev/null 2>&1; then
        # If jq is available, parse the JSON file
        LLAMA_MODEL=$(jq -r '.model' "$LLAMA_CONFIG_FILE")
        LLAMA_ALIAS=$(jq -r '.alias' "$LLAMA_CONFIG_FILE")
        LLAMA_MMPROJ=$(jq -r '.mmproj' "$LLAMA_CONFIG_FILE")
        LLAMA_TEMP=$(jq -r '.temp' "$LLAMA_CONFIG_FILE")
        LLAMA_TOP_P=$(jq -r '.top_p' "$LLAMA_CONFIG_FILE")
        LLAMA_TOP_K=$(jq -r '.top_k' "$LLAMA_CONFIG_FILE")
        LLAMA_MIN_P=$(jq -r '.min_p' "$LLAMA_CONFIG_FILE")
        LLAMA_REPETITION_PENALTY=$(jq -r '.repetition_penalty' "$LLAMA_CONFIG_FILE")
        LLAMA_PRESENCE_PENALTY=$(jq -r '.presence_penalty' "$LLAMA_CONFIG_FILE")
        LLAMA_KV_UNIFIED=$(jq -r '.kv_unified' "$LLAMA_CONFIG_FILE")
        LLAMA_CACHE_TYPE_K=$(jq -r '.cache_type_k' "$LLAMA_CONFIG_FILE")
        LLAMA_CACHE_TYPE_V=$(jq -r '.cache_type_v' "$LLAMA_CONFIG_FILE")
        LLAMA_FLASH_ATTN=$(jq -r '.flash_attn' "$LLAMA_CONFIG_FILE")
        LLAMA_FIT=$(jq -r '.fit' "$LLAMA_CONFIG_FILE")
        LLAMA_BATCH_SIZE=$(jq -r '.batch_size' "$LLAMA_CONFIG_FILE")
        LLAMA_UBATCH_SIZE=$(jq -r '.ubatch_size' "$LLAMA_CONFIG_FILE")
        LLAMA_CTX_SIZE=$(jq -r '.ctx_size' "$LLAMA_CONFIG_FILE")
        LLAMA_N_GPU_LAYERS=$(jq -r '.n_gpu_layers' "$LLAMA_CONFIG_FILE")
    fi
fi

# Validate that required parameters are set
if [ -z "$LLAMA_MODEL" ]; then
    echo "ERROR: Llama model path is not configured"
    exit 1
fi

# Build command arguments based on parameters
ARGS=(
    "-m" "$LLAMA_MODEL"
    "--alias" "$LLAMA_ALIAS"
    "--host" "0.0.0.0"
    "--port" "$LLAMA_PORT"
    "--batch-size" "$LLAMA_BATCH_SIZE"
    "--ubatch-size" "$LLAMA_UBATCH_SIZE"
    "--temp" "$LLAMA_TEMP"
    "--top-p" "$LLAMA_TOP_P"
    "--min-p" "$LLAMA_MIN_P"
    "--cache-type-k" "$LLAMA_CACHE_TYPE_K"
    "--cache-type-v" "$LLAMA_CACHE_TYPE_V"
    "--models-max" "1"
    "--image-min-tokens" "1024"
)

# Add optional parameters
if [ -n "$LLAMA_CTX_SIZE" ] && [ "$LLAMA_CTX_SIZE" -ge 1 ]; then ARGS+=("--ctx-size" "$LLAMA_CTX_SIZE"); fi
if [ "$LLAMA_FLASH_ATTN" = "true" ]; then ARGS+=("-fa" "on"); else ARGS+=("-fa" "off"); fi
if [ "$LLAMA_MMPROJ" != "" ]; then ARGS+=("--mmproj" "$LLAMA_MMPROJ"); fi
if [ "$LLAMA_KV_UNIFIED" = "true" ]; then ARGS+=("--kv-unified"); fi
if [ "$LLAMA_FIT" = "false" ]; then ARGS+=("--fit" "off"); else ARGS+=("--fit" "on"); fi
if [ "$LLAMA_REASONING" = "1" ]; then ARGS+=("--reasoning" "on"); elif [ "$LLAMA_REASONING" = "0" ]; then ARGS+=("--reasoning" "off"); fi
if [ "$LLAMA_WEBUI" = "false" ]; then ARGS+=("--no-webui"); fi
if [ -n "$LLAMA_LOG_LEVEL" ] && [ "$LLAMA_LOG_LEVEL" -ge 0 ]; then ARGS+=("--log-prefix" "--verbosity" "$LLAMA_LOG_LEVEL"); else ARGS+=("--log-disable"); fi
if [ -n "$LLAMA_N_GPU_LAYERS" ] && [ "$LLAMA_N_GPU_LAYERS" -ge 0 ]; then ARGS+=("--n-gpu-layers" "$LLAMA_N_GPU_LAYERS"); fi
if [ -n "$LLAMA_MODEL_UNLOAD_IDLE_S" ] && [ "$LLAMA_MODEL_UNLOAD_IDLE_S" -ge 0 ]; then ARGS+=("--sleep-idle-seconds" "$LLAMA_MODEL_UNLOAD_IDLE_S"); fi

# Exporting as session environment variables so they get removed on container exit.
if [ "$CUDA_FORCE_FP16" = "true" ] || [ "$CUDA_SHARED_MEMORY" = "true" ]; then
    # DEBUG
    # echo "--- Current CUDA Environment Variables ---"
    # printenv | grep GGML || true
    # echo "------------------------------------------"
    if [ "$CUDA_FORCE_FP16" = "true" ]; then
        echo "--- FORCING FP16 COMPUTE -----------------"
        export GGML_CUDA_FORCE_CUBLAS_COMPUTE_16F=1
    fi

    if [ "$CUDA_SHARED_MEMORY" = "true" ]; then
        echo "--- ENABLING UNIFIED MEMORY --------------"
        export GGML_CUDA_ENABLE_UNIFIED_MEMORY=1
    fi

    echo "--- NEW CUDA Environment Variables -------"
    printenv | grep GGML || true
    echo "------------------------------------------"
fi

echo "INFO: Starting llama-server in the foreground with model: $LLAMA_MODEL"
echo "INFO: Starting parameters: ${ARGS[@]}"

# Temporarily disable "exit on error"
set +e

/opt/llama.cpp/llama-server "${ARGS[@]}"

# capture the exit code
EXIT_CODE=$?

if [ $EXIT_CODE -ne 0 ]; then
    # Check for Abort (134), OOM Killer (137), or Segfault (139)
    if [ $EXIT_CODE -eq 134 ] || [ $EXIT_CODE -eq 137 ] || [ $EXIT_CODE -eq 139 ]; then
        echo ""
        echo "=========================================================="
        echo "❌ CRASH DETECTED: Exit Code $EXIT_CODE"
        echo "💡 The server likely ran out of GPU VRAM (OOM)"
        echo "   Try tweaking model.json settings in this order:"
        echo "   - reducing the context size (ctx_size)"
        echo "   - offloading fewer layers to gpu (n_gpu_layers)"
        echo "   - using a smaller, more quantized model or version"
        echo "   - using a different model"
        echo "   Or in compose.yml"
        echo "   - Force fp16 calculations (CUDA_FORCE_FP16)"
        echo "   - Enabling shared VRAM+RAM (CUDA_SHARED_MEMORY)"
        echo "     (will degrade performance, but stops OOM crashes"
        echo "     if you have enough RAM)"
        echo "   Post your startup or crash log into any ai web chat"
        echo "   (If it is stupid but it works, it is not stupid)"     
        echo "=========================================================="

    elif [ $EXIT_CODE -ne 0 ]; then
        # Optional: Catch any other abnormal crash
        echo "❌ SERVER CRASHED with Exit Code $EXIT_CODE."
    fi

    echo ""
    echo "⚙️  Starting parameters were:"
    echo "   ${ARGS[@]}"
    echo "⚙️   CUDA Environment Variables were:"
    printenv | grep GGML || true
fi

# Exit the script with the exact same code
    echo "EXITING CONTAINER"
exit $EXIT_CODE