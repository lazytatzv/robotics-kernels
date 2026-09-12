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
RT_MAJOR="7.0"
RT_PATCH="patch-7.0.1-rt2.patch.xz"

echo "Building target: $TARGET"
echo "Kernel: $KERNEL_VERSION / RT Patch: $RT_PATCH"

# 1. Download source and patch
wget -q https://cdn.kernel.org/pub/linux/kernel/v${KERNEL_MAJOR}/linux-${KERNEL_VERSION}.tar.xz
wget -q https://mirrors.edge.kernel.org/pub/linux/kernel/projects/rt/${RT_MAJOR}/${RT_PATCH}

# 2. Extract and apply patch
tar -xf linux-${KERNEL_VERSION}.tar.xz
cd linux-${KERNEL_VERSION}
xzcat ../${RT_PATCH} | patch -p1 > /dev/null

# 3. Copy base config
cp ../${TARGET}/.config .config

# 4. Apply custom configurations
# Base Real-Time configuration
./scripts/config --enable CONFIG_PREEMPT_RT
./scripts/config --set-str CONFIG_LOCALVERSION "-rt-robotics"

# Timer & Scheduler Tuning (1000Hz, Full Tickless, RCU Offloading)
./scripts/config --disable CONFIG_HZ_250
./scripts/config --disable CONFIG_HZ_300
./scripts/config --enable CONFIG_HZ_1000
./scripts/config --set-val CONFIG_HZ 1000
./scripts/config --enable CONFIG_NO_HZ_FULL
./scripts/config --enable CONFIG_RCU_NOCB_CPU

# CPU Performance Governor by default (minimize latency spikes)
./scripts/config --disable CONFIG_CPU_FREQ_DEFAULT_GOV_POWERSAVE
./scripts/config --disable CONFIG_CPU_FREQ_DEFAULT_GOV_SCHEDUTIL
./scripts/config --enable CONFIG_CPU_FREQ_DEFAULT_GOV_PERFORMANCE

# Robotics & Industrial Communications (SocketCAN & USB-CAN adapters)
./scripts/config --enable CONFIG_CAN
./scripts/config --enable CONFIG_CAN_RAW
./scripts/config --enable CONFIG_CAN_BCM
./scripts/config --enable CONFIG_CAN_GW
./scripts/config --enable CONFIG_CAN_DEV
./scripts/config --enable CONFIG_CAN_CALC_BITTIMING
./scripts/config --module CONFIG_CAN_GS_USB
./scripts/config --module CONFIG_CAN_PEAK_USB
./scripts/config --module CONFIG_CAN_SLCAN
./scripts/config --module CONFIG_CAN_KVASER_USB

# High-Precision Timing & Time Synchronization (PTP / IEEE 1588 for EtherCAT/TSN)
./scripts/config --enable CONFIG_NETWORK_PHY_TIMESTAMPING
./scripts/config --enable CONFIG_PTP_1588_CLOCK

# Real-Time Latency Analysis & Tracers (rtla / cyclictest / timerlat)
./scripts/config --enable CONFIG_FTRACE
./scripts/config --enable CONFIG_SCHED_TRACER
./scripts/config --enable CONFIG_HWLAT_TRACER
./scripts/config --enable CONFIG_OSNOISE_TRACER
./scripts/config --enable CONFIG_TIMERLAT_TRACER

# Remove heavy debug locks and overhead for production RT
./scripts/config --disable CONFIG_DEBUG_INFO
./scripts/config --disable CONFIG_DEBUG_INFO_BTF
./scripts/config --disable CONFIG_PROVE_LOCKING
./scripts/config --disable CONFIG_LOCKDEP
./scripts/config --disable CONFIG_DEBUG_ATOMIC_SLEEP
./scripts/config --set-str CONFIG_SYSTEM_TRUSTED_KEYS ""
./scripts/config --set-str CONFIG_SYSTEM_REVOCATION_KEYS ""

# Resolve configuration differences automatically
make olddefconfig > /dev/null

# 5. Build Debian packages
make -j$(nproc) bindeb-pkg

echo "Build completed."
