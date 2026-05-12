# ==========================================
# STAGE 1: Builder
# DEV environment to build llama.cpp
# ==========================================
ARG BASE_BUILD_IMAGE="nvidia/cuda:13.1.2-devel-ubuntu24.04"
ARG BASE_RUN_IMAGE="nvidia/cuda:13.1.2-runtime-ubuntu24.04"

FROM ${BASE_BUILD_IMAGE} AS builder

ARG CUDA_ARCH

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    build-essential cmake curl libcurl4-openssl-dev git \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt
# Pass the CUDA_ARCH to CMake
RUN git clone https://github.com/ggml-org/llama.cpp \
    && cmake llama.cpp -B llama.cpp/build \
        -DBUILD_SHARED_LIBS=OFF \
        -DGGML_CUDA=ON \
        -DGGML_CUDA_GRAPH=ON \
        -DGGML_CUDA_USE_CUBLASLT=ON \
        -DGGML_CUDA_FA_ALL_VARIANTS=ON \
        -DGGML_AVX512=ON \
        -DGGML_AVX512_VBMI=ON \
        -DGGML_AVX512_VNNI=ON \
        -DGGML_LTO=ON \
        -DGGML_OPENMP=ON \
        -DCMAKE_C_FLAGS="-march=native -O3" \
        -DCMAKE_CXX_FLAGS="-march=native -O3" \
        -DCMAKE_CUDA_ARCHITECTURES=${CUDA_ARCH} \
    && cmake --build llama.cpp/build --config Release -j 8 --clean-first \
        --target llama-cli llama-mtmd-cli llama-server llama-gguf-split

# ==========================================
# STAGE 2: Runtime
# Lightweight environment run the server
# ==========================================

FROM ${BASE_RUN_IMAGE}

ARG UID=1000
ARG GID=1000
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    pciutils curl libcurl4 python3 python3-pip jq vim \
    && rm -rf /var/lib/apt/lists/*

# Safely create llamauser
RUN (userdel -r ubuntu || true) \
    && groupadd -g ${GID} llamauser || true \
    && useradd -u ${UID} -g ${GID} -m -s /bin/bash llamauser

WORKDIR /opt/llama.cpp

# Copy ONLY the compiled binaries from the builder stage
COPY --from=builder /opt/llama.cpp/build/bin/llama-* ./

# Setup global environment variables so any bash session gets them
RUN echo 'export LLAMA_API_KEY=${LLAMA_API_KEY}' >> /etc/bash.bashrc \
    && echo 'export GGML_CUDA_FORCE_CUBLAS_COMPUTE_16F=${GGML_CUDA_FORCE_CUBLAS_COMPUTE_16F}' >> /etc/bash.bashrc

# Setup entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh \
    && chown -R llamauser:llamauser /opt/llama.cpp

WORKDIR /home/llamauser
ENTRYPOINT ["/entrypoint.sh"]