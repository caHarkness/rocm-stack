#!/bin/bash

export APP_NAME="comfyui"

cd "$(dirname "$0")"

source ./options.sh-example
source ./options.sh
source ./daemon.sh

./rocm.sh --check || exit

if [[ ! -d ComfyUI || "$@" =~ "--update" ]]
then
    git clone https://github.com/Comfy-Org/ComfyUI.git

    cd ComfyUI

    if [[ "$@" =~ "--update" ]]
    then
        # Make sure it's up to date:
        git pull
    fi

    apt install python3-venv
    rm -rf venv
    python3 -m venv venv

    source ./venv/bin/activate

    # Updating versions may require investigating repo by hand:
    pip install --index-url https://stable.repo.amd.com/rocm/whl-next/ \
        "torch[device-${AMD_GPU}]==2.13.0+rocm${ROCM_VERSION}.0" \
        "torchvision[device-${AMD_GPU}]==0.28.0+${ROCM_VERSION}.0" \
        "torchaudio==2.11.0.2+${ROCM_VERSION}.0"
        
    pip install -r requirements.txt
    
    cd ..

    if [[ "$@" =~ "--update" ]]
    then
        exit 0
    fi
fi

cd ComfyUI

source ./venv/bin/activate

mkdir -p user

python -u main.py \
    --listen \
    --port 8188 \
    --gpu-only \
    --disable-smart-memory \
    --disable-mmap \
    --enable-manager \
    --user-directory user
