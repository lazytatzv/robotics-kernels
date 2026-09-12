#!/usr/bin/env bash
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

# CPU Performance & Maximum Clock Power (Intel/AMD P-State, Turbo Boost Max)
./scripts/config --enable CONFIG_X86_INTEL_PSTATE
./scripts/config --enable CONFIG_X86_AMD_PSTATE
./scripts/config --enable CONFIG_INTEL_TURBO_MAX_3
./scripts/config --enable CONFIG_SCHED_MC
./scripts/config --enable CONFIG_SCHED_MC_PRIO
./scripts/config --enable CONFIG_SCHED_SMT
./scripts/config --enable CONFIG_CPU_FREQ_DEFAULT_GOV_PERFORMANCE
./scripts/config --enable CONFIG_CPU_FREQ_GOV_PERFORMANCE
./scripts/config --disable CONFIG_CPU_FREQ_DEFAULT_GOV_POWERSAVE
./scripts/config --disable CONFIG_CPU_FREQ_DEFAULT_GOV_SCHEDUTIL
./scripts/config --disable CONFIG_CPU_FREQ_GOV_POWERSAVE
./scripts/config --disable CONFIG_CPU_FREQ_GOV_USERSPACE
./scripts/config --disable CONFIG_CPU_FREQ_GOV_ONDEMAND
./scripts/config --disable CONFIG_CPU_FREQ_GOV_CONSERVATIVE
./scripts/config --disable CONFIG_CPU_FREQ_GOV_SCHEDUTIL

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

# ROS 2 & DDS IPC / Zero-Copy Support (Priority Inheritance, POSIX MQueue, memfd)
./scripts/config --enable CONFIG_FUTEX
./scripts/config --enable CONFIG_FUTEX_PI
./scripts/config --enable CONFIG_POSIX_MQUEUE
./scripts/config --enable CONFIG_MEMFD_CREATE
./scripts/config --enable CONFIG_IP_MULTICAST

# Docker & Container Support (Namespaces, Cgroups, OverlayFS, Bridge/Veth)
./scripts/config --enable CONFIG_NAMESPACES
./scripts/config --enable CONFIG_CGROUPS
./scripts/config --enable CONFIG_MEMCG
./scripts/config --enable CONFIG_CPUSETS
./scripts/config --enable CONFIG_CGROUP_SCHED
./scripts/config --enable CONFIG_FAIR_GROUP_SCHED
./scripts/config --enable CONFIG_RT_GROUP_SCHED
./scripts/config --enable CONFIG_SECCOMP
./scripts/config --module CONFIG_OVERLAY_FS
./scripts/config --module CONFIG_BRIDGE
./scripts/config --module CONFIG_VETH
./scripts/config --module CONFIG_NETFILTER
./scripts/config --module CONFIG_IP_NF_IPTABLES

# Disable completely unused subsystems & legacy hardware (Keep USB, CAN, Ether, WiFi, BT, V4L2)
# 1. TV / Radio / DVB tuners (V4L2 camera support is kept)
./scripts/config --disable CONFIG_MEDIA_DIGITAL_TV_SUPPORT
./scripts/config --disable CONFIG_MEDIA_ANALOG_TV_SUPPORT
./scripts/config --disable CONFIG_MEDIA_RADIO_SUPPORT
./scripts/config --disable CONFIG_DVB_CORE

# 2. Legacy buses & archaic networking
./scripts/config --disable CONFIG_FIREWIRE
./scripts/config --disable CONFIG_PCMCIA
./scripts/config --disable CONFIG_HAMRADIO
./scripts/config --disable CONFIG_ATM
./scripts/config --disable CONFIG_ISDN
./scripts/config --disable CONFIG_APPLETALK
./scripts/config --disable CONFIG_AX25

# 3. Unused / Legacy filesystems (keep ext4, vfat, overlayfs)
./scripts/config --disable CONFIG_BTRFS_FS
./scripts/config --disable CONFIG_XFS_FS
./scripts/config --disable CONFIG_JFS_FS
./scripts/config --disable CONFIG_REISERFS_FS
./scripts/config --disable CONFIG_HFS_FS
./scripts/config --disable CONFIG_HFSPLUS_FS
./scripts/config --disable CONFIG_NILFS2_FS
./scripts/config --disable CONFIG_UFS_FS
./scripts/config --disable CONFIG_MINIX_FS

# 4. Hypervisors & Sleep States (Bare-metal robotics target, avoid freeze/hibernation)
./scripts/config --disable CONFIG_KVM
./scripts/config --disable CONFIG_KVM_INTEL
./scripts/config --disable CONFIG_KVM_AMD
./scripts/config --disable CONFIG_XEN
./scripts/config --disable CONFIG_HIBERNATION

# Extreme Real-Time Tuning for Robotics Competition (Deterministic Execution)
# 1. PCIe & Power Management: Highest Performance / No latency spikes
./scripts/config --enable CONFIG_PCIEASPM_PERFORMANCE
./scripts/config --disable CONFIG_PCIEASPM_POWERSAVE
./scripts/config --disable CONFIG_PCIEASPM_POWER_SUPERSAVE

# 2. Disable SWAP (Prevent deadly disk I/O stall & memory freeze during matches)
./scripts/config --disable CONFIG_SWAP

# 3. Threaded IRQs (Allow prioritizing control tasks over network/USB interrupts)
./scripts/config --enable CONFIG_IRQ_FORCED_THREADING

# 4. Remove watchdog & detector timer interrupts (Eliminate background NMI jitter)
./scripts/config --disable CONFIG_LOCKUP_DETECTOR
./scripts/config --disable CONFIG_HARDLOCKUP_DETECTOR
./scripts/config --disable CONFIG_DETECT_HUNG_TASK

# 5. Disable CPU Vulnerability Mitigations for Ultra-Fast Syscalls & Context Switches
./scripts/config --disable CONFIG_PAGE_TABLE_ISOLATION
./scripts/config --disable CONFIG_RETPOLINE

# 6. Ultra-Fast Memory Allocation & Cache Optimization (HugePages, SLUB, Disable NUMA)
./scripts/config --enable CONFIG_TRANSPARENT_HUGEPAGE_ALWAYS
./scripts/config --disable CONFIG_SLAB_FREELIST_HARDENED
./scripts/config --disable CONFIG_SLAB_FREELIST_RANDOM
./scripts/config --disable CONFIG_NUMA

# 7. Pure Real-Time Scheduler & Compiler Performance Optimization
./scripts/config --disable CONFIG_SCHED_AUTOGROUP
./scripts/config --enable CONFIG_CC_OPTIMIZE_FOR_PERFORMANCE

# Remove heavy debug locks and overhead for production RT
./scripts/config --disable CONFIG_DEBUG_INFO
./scripts/config --disable CONFIG_DEBUG_INFO_BTF
./scripts/config --disable CONFIG_PROVE_LOCKING
./scripts/config --disable CONFIG_LOCKDEP
./scripts/config --disable CONFIG_DEBUG_ATOMIC_SLEEP
./scripts/config --disable CONFIG_PAGE_POISONING
./scripts/config --disable CONFIG_DEBUG_KMEMLEAK
./scripts/config --set-str CONFIG_SYSTEM_TRUSTED_KEYS ""
./scripts/config --set-str CONFIG_SYSTEM_REVOCATION_KEYS ""

# Resolve configuration differences automatically
make olddefconfig > /dev/null

# 5. Build Debian packages with modern x86-64-v3 (AVX2/FMA) optimization
KCFLAGS="-O3 -march=x86-64-v3 -mtune=generic" KCPPFLAGS="-O3 -march=x86-64-v3 -mtune=generic" make -j$(nproc) bindeb-pkg

echo "Build completed."
