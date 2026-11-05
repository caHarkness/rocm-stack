#!/bin/bash

cd "$(dirname "$0")"

source ./options.sh-example
source ./options.sh

if [[ "$@" =~ "--check" ]]
then
    if [[ ! -d "/opt/rocm/core-${ROCM_VERSION}" ]]
    then
        echo "ROCm not detected, install with ./rocm.sh --install"
        exit 1
    fi

    exit 0
fi

if [[ "$@" =~ "--install" ]]
then
    apt update

    # Add the ROCm 10.x official repo:
    cat << EOF > /etc/apt/sources.list.d/amdrocm-stable.sources
X-Repo-Id: amdrocm-stable
Types: deb
URIs: https://stable.repo.amd.com/rocm/core/packages/debian13/
Suites: stable
Components: main
Architectures: amd64
Enabled: yes
Signed-By:
$(wget https://stable.repo.amd.com/rocm/gpg/packages.gpg -O - | sed 's/^/ /')
EOF

    # Install the required dependencies for a ROCm/HIP build:
    apt install -y amdrocm-core-sdk${ROCM_VERSION}-${AMD_GPU}
    apt install -y amdrocm-core-dev${ROCM_VERSION}-${AMD_GPU}
    apt install -y amdrocm${ROCM_VERSION}-${AMD_GPU}

    exit 0
fi

echo "Usage: ./rocm.sh --install"
exit 1
