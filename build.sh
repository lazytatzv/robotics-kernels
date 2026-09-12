#!/bin/bash
set -e

TARGET=$1
if [ -z "$TARGET" ]; then
    echo "Usage: $0 <target_directory> (e.g., $0 x86_64-ubuntu2604)"
    exit 1
fi

# Kernel version variables
KERNEL_MAJOR="7.x"
KERNEL_VERSION="7.0.1"
RT_PATCH="patch-7.0.1-rt2.patch.xz"

echo "Building target: $TARGET"
echo "Kernel: $KERNEL_VERSION / RT Patch: $RT_PATCH"

# 1. Download source and patch
wget -q https://cdn.kernel.org/pub/linux/kernel/v${KERNEL_MAJOR}/linux-${KERNEL_VERSION}.tar.xz
wget -q https://mirrors.edge.kernel.org/pub/linux/kernel/projects/rt/6.12/${RT_PATCH}

# 2. Extract and apply patch
tar -xf linux-${KERNEL_VERSION}.tar.xz
cd linux-${KERNEL_VERSION}
xzcat ../${RT_PATCH} | patch -p1 > /dev/null

# 3. Copy base config
cp ../${TARGET}/.config .config

# 4. Apply custom configurations
./scripts/config --enable CONFIG_PREEMPT_RT
./scripts/config --set-str CONFIG_LOCALVERSION "-rt-robotics"
./scripts/config --disable CONFIG_DEBUG_INFO
./scripts/config --disable CONFIG_DEBUG_INFO_BTF
./scripts/config --set-str CONFIG_SYSTEM_TRUSTED_KEYS ""
./scripts/config --set-str CONFIG_SYSTEM_REVOCATION_KEYS ""

# Resolve configuration differences automatically
make olddefconfig > /dev/null

# 5. Build Debian packages
make -j$(nproc) bindeb-pkg

echo "Build completed."
