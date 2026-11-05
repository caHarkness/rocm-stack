#!/bin/bash

export APP_NAME="llamacpp"

cd "$(dirname "$0")"

source ./options.sh-example
source ./options.sh
source ./daemon.sh

./rocm.sh --check || exit

if [[ ! -d llama.cpp || "$@" =~ "--update" || "$@" =~ "--rebuild" ]]
then
    # Install the common build dependencies:
    apt install build-essential ca-certificates cmake curl git libcurl4-openssl-dev libdrm-dev libdw-dev libelf-dev libgl-dev libnuma-dev libpciaccess-dev libssl-dev libudev-dev libzstd-dev ninja-build pciutils pkg-config python3 python3-pip python3-venv xxd zlib1g-dev libvulkan-dev glslc libshaderc-dev libshaderc1 php8.4-cli

    # Clone llama.cpp
    git clone https://github.com/ggml-org/llama.cpp.git

    cd llama.cpp

    if [[ "$@" =~ "--update" ]]
    then
        git pull
    fi

    cd tools/ui
    npm install
    npm run build
    cd ../..

    # Create a "build" configuration for ROCm:
    cmake -B build \
        -DCMAKE_BUILD_TYPE=Release \
        -DGGML_VULKAN=ON \
        -DGGML_HIP=ON \
        -DAMD_GPU_TARGETS=${AMD_GPU}

    # Actually build the "build" ROCm configuration (using 8 threads):
    cmake --build build --config Release --parallel 8

    cd ..

    if [[ "$@" =~ "--update" || "$@" =~ "--rebuild" ]]
    then
        exit 0
    fi
fi

export HIP_VISIBLE_DEVICES=0,1

# Settings for changing running mode:
export DEVICE="ROCm"

if [[ "$@" =~ "--vulkan" ]]
then
    export DEVICE="Vulkan"
fi

export DEVICE_0="${DEVICE}0"
export DEVICE_1="${DEVICE}1"
export USE_DEVICE="${DEVICE_0},${DEVICE_1}"
export MTP_DEVICE="${DEVICE_1}"

USE_DEVICE="${DEVICE_0}"
MTP_DEVICE="${DEVICE_0}"

if [[ ! -f "models.ini" ]]; then cp models.ini-example models.ini; fi
if [[ ! -f "config.json" ]]; then cp config.json-example config.json; fi

export GGML_CUDA_DISABLE_GRAPHS=1

./llama.cpp/build/bin/llama-server \
    --host 0.0.0.0 \
    --port 9931 \
    --webui-mcp-proxy \
    --webui-config-file "config.json" \
    --models-preset "models.ini" \
    --models-max 1 \
    --device "${USE_DEVICE}" \
    --spec-draft-device "${MTP_DEVICE}"
