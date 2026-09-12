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

# Build environment variables (ensures reproducibility)
export KBUILD_BUILD_USER="robotics"
export KBUILD_BUILD_HOST="robotics-builder"
export KDEB_CHANGELOG_DIST="noble"

echo "Building target: $TARGET"
echo "Kernel: $KERNEL_VERSION / RT Patch: $RT_PATCH"

# 1. Download source and patch (skip if already cached)
KERNEL_TAR="linux-${KERNEL_VERSION}.tar.xz"
if [ ! -f "$KERNEL_TAR" ]; then
    echo "Downloading kernel source ($KERNEL_TAR)..."
    wget -c -q --show-progress "https://cdn.kernel.org/pub/linux/kernel/v${KERNEL_MAJOR}/${KERNEL_TAR}"
else
    echo "Using cached kernel source ($KERNEL_TAR)"
fi

if [ ! -f "$RT_PATCH" ]; then
    echo "Downloading RT patch ($RT_PATCH)..."
    wget -c -q --show-progress "https://mirrors.edge.kernel.org/pub/linux/kernel/projects/rt/${RT_MAJOR}/${RT_PATCH}"
else
    echo "Using cached RT patch ($RT_PATCH)"
fi

# 2. Extract and apply patch (multi-threaded decompression with xz -T0)
rm -rf "linux-${KERNEL_VERSION}"
echo "Extracting kernel source with all CPU cores..."
tar -I "xz -T0" -xf "$KERNEL_TAR"
cd "linux-${KERNEL_VERSION}"
echo "Applying PREEMPT_RT patch..."
xzcat "../${RT_PATCH}" | patch -p1 > /dev/null

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
./scripts/config --enable CONFIG_NETFILTER
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

# 3. Unused / Heavy server filesystems (keep ext4, vfat, overlayfs)
./scripts/config --disable CONFIG_BTRFS_FS
./scripts/config --disable CONFIG_XFS_FS
./scripts/config --disable CONFIG_JFS_FS
./scripts/config --disable CONFIG_REISERFS_FS
./scripts/config --disable CONFIG_HFS_FS
./scripts/config --disable CONFIG_HFSPLUS_FS
./scripts/config --disable CONFIG_NILFS2_FS
./scripts/config --disable CONFIG_UFS_FS
./scripts/config --disable CONFIG_MINIX_FS
./scripts/config --disable CONFIG_F2FS_FS
./scripts/config --disable CONFIG_OCFS2_FS
./scripts/config --disable CONFIG_GFS2_FS
./scripts/config --disable CONFIG_CEPH_FS
./scripts/config --disable CONFIG_CIFS
./scripts/config --disable CONFIG_SMB_SERVER
./scripts/config --disable CONFIG_NFS_FS
./scripts/config --disable CONFIG_NFSD

# 4. Heavy enterprise server Ethernet & Infiniband (Keep Intel & Realtek)
./scripts/config --disable CONFIG_INFINIBAND
./scripts/config --disable CONFIG_NET_VENDOR_CISCO
./scripts/config --disable CONFIG_NET_VENDOR_MELLANOX
./scripts/config --disable CONFIG_NET_VENDOR_BROADCOM
./scripts/config --disable CONFIG_NET_VENDOR_CHELSIO
./scripts/config --disable CONFIG_NET_VENDOR_QLOGIC
./scripts/config --disable CONFIG_NET_VENDOR_NETRONOME
./scripts/config --disable CONFIG_NET_VENDOR_SOLARFLARE
./scripts/config --disable CONFIG_NET_VENDOR_MARVELL
./scripts/config --disable CONFIG_NET_VENDOR_CAVIUM
./scripts/config --disable CONFIG_NET_VENDOR_ALACRITECH

# 5. Unused GPUs & Display Drivers (Keep Intel i915/Xe, AMD amdgpu, and NVIDIA official; disable all VM, ARM, and legacy GPUs)
# Unused / Obsolete PC GPUs
./scripts/config --disable CONFIG_DRM_NOUVEAU
./scripts/config --disable CONFIG_DRM_RADEON
./scripts/config --disable CONFIG_DRM_AST
./scripts/config --disable CONFIG_DRM_MGAG200
./scripts/config --disable CONFIG_DRM_QXL
./scripts/config --disable CONFIG_DRM_BOCHS
./scripts/config --disable CONFIG_DRM_VIRTIO_GPU
./scripts/config --disable CONFIG_DRM_ASPEED_GFX

# Virtual Machine GPUs (VMware, VirtualBox, QEMU, Hyper-V, Xen)
./scripts/config --disable CONFIG_DRM_VMWGFX
./scripts/config --disable CONFIG_DRM_VBOXVIDEO
./scripts/config --disable CONFIG_DRM_CIRRUS_QEMU
./scripts/config --disable CONFIG_DRM_HYPERV
./scripts/config --disable CONFIG_DRM_XEN

# Non-x86 / ARM SoC GPUs (Raspberry Pi, Mali, Allwinner, MediaTek, etc.)
./scripts/config --disable CONFIG_DRM_VC4
./scripts/config --disable CONFIG_DRM_V3D
./scripts/config --disable CONFIG_DRM_LIMA
./scripts/config --disable CONFIG_DRM_PANFROST
./scripts/config --disable CONFIG_DRM_PANTHOR
./scripts/config --disable CONFIG_DRM_SUN4I
./scripts/config --disable CONFIG_DRM_MESON
./scripts/config --disable CONFIG_DRM_MEDIATEK
./scripts/config --disable CONFIG_DRM_ETNAVIV
./scripts/config --disable CONFIG_DRM_HISI
./scripts/config --disable CONFIG_DRM_PL111
./scripts/config --disable CONFIG_DRM_TIDSS

# Ancient Intel Atom / Legacy GMA GPUs
./scripts/config --disable CONFIG_DRM_GMA500
./scripts/config --disable CONFIG_DRM_GMA3600
./scripts/config --disable CONFIG_DRM_GMA600
./scripts/config --disable CONFIG_DRM_I810

# 6. Heavy server RAID controllers (Keep NVMe & SATA/AHCI)
./scripts/config --disable CONFIG_SCSI_MEGARAID
./scripts/config --disable CONFIG_SCSI_AACRAID
./scripts/config --disable CONFIG_SCSI_QLOGIC_1280
./scripts/config --disable CONFIG_SCSI_AIC7XXX
./scripts/config --disable CONFIG_SCSI_MVSAS

# 7. Hypervisors & Sleep States (Bare-metal robotics target, avoid freeze/hibernation)
./scripts/config --disable CONFIG_KVM
./scripts/config --disable CONFIG_KVM_INTEL
./scripts/config --disable CONFIG_KVM_AMD
./scripts/config --disable CONFIG_XEN
./scripts/config --disable CONFIG_HIBERNATION

# 8. Archaic Media, Obscure NICs, 90s Joysticks & Legacy Laptop Drivers
# Archaic storage & media (Floppy, CD-ROM, IDE, MemoryStick)
./scripts/config --disable CONFIG_BLK_DEV_FD
./scripts/config --disable CONFIG_CDROM
./scripts/config --disable CONFIG_BLK_DEV_SR
./scripts/config --disable CONFIG_IDE
./scripts/config --disable CONFIG_PATA_LEGACY
./scripts/config --disable CONFIG_MEMSTICK

# Unused wireless / NFC / WiMAX
./scripts/config --disable CONFIG_WIMAX
./scripts/config --disable CONFIG_NFC

# Archaic joysticks (Keep modern USB/BT gamepads: xpad, sony, hid)
./scripts/config --disable CONFIG_JOYSTICK_IFORCE
./scripts/config --disable CONFIG_JOYSTICK_WARRIOR
./scripts/config --disable CONFIG_JOYSTICK_MAGELLAN
./scripts/config --disable CONFIG_JOYSTICK_SPACEORB
./scripts/config --disable CONFIG_JOYSTICK_SPACEBALL
./scripts/config --disable CONFIG_JOYSTICK_STINGER
./scripts/config --disable CONFIG_JOYSTICK_TWIDDLER
./scripts/config --disable CONFIG_JOYSTICK_ZHENHUA
./scripts/config --disable CONFIG_JOYSTICK_DB9
./scripts/config --disable CONFIG_JOYSTICK_GAMECON
./scripts/config --disable CONFIG_JOYSTICK_TURBOGRAFX

# Archaic 90s-2000s GPUs (Voodoo, Matrox, S3, Riva, etc.)
./scripts/config --disable CONFIG_FB_MATROX
./scripts/config --disable CONFIG_FB_RIVA
./scripts/config --disable CONFIG_FB_I740
./scripts/config --disable CONFIG_FB_KYRO
./scripts/config --disable CONFIG_FB_S3
./scripts/config --disable CONFIG_FB_VOODOO1
./scripts/config --disable CONFIG_FB_TRIDENT

# Obscure NIC vendors (Keep Intel e1000/igb/ixgbe/ice and Realtek r8169)
./scripts/config --disable CONFIG_NET_VENDOR_AQUANTIA
./scripts/config --disable CONFIG_NET_VENDOR_AGERE
./scripts/config --disable CONFIG_NET_VENDOR_ALTEON
./scripts/config --disable CONFIG_NET_VENDOR_DEC
./scripts/config --disable CONFIG_NET_VENDOR_DLINK
./scripts/config --disable CONFIG_NET_VENDOR_EMULEX
./scripts/config --disable CONFIG_NET_VENDOR_EZCHIP
./scripts/config --disable CONFIG_NET_VENDOR_HUAWEI
./scripts/config --disable CONFIG_NET_VENDOR_MYRICOM
./scripts/config --disable CONFIG_NET_VENDOR_NATSEMI
./scripts/config --disable CONFIG_NET_VENDOR_NVIDIA
./scripts/config --disable CONFIG_NET_VENDOR_OKI
./scripts/config --disable CONFIG_NET_VENDOR_PENSANDO
./scripts/config --disable CONFIG_NET_VENDOR_QUALCOMM
./scripts/config --disable CONFIG_NET_VENDOR_RDC
./scripts/config --disable CONFIG_NET_VENDOR_RENESAS
./scripts/config --disable CONFIG_NET_VENDOR_ROCKER
./scripts/config --disable CONFIG_NET_VENDOR_SAMSUNG
./scripts/config --disable CONFIG_NET_VENDOR_SEEQ
./scripts/config --disable CONFIG_NET_VENDOR_SILAN
./scripts/config --disable CONFIG_NET_VENDOR_SIS
./scripts/config --disable CONFIG_NET_VENDOR_SMSC
./scripts/config --disable CONFIG_NET_VENDOR_STMICRO
./scripts/config --disable CONFIG_NET_VENDOR_SUN
./scripts/config --disable CONFIG_NET_VENDOR_TEHUTI
./scripts/config --disable CONFIG_NET_VENDOR_TI
./scripts/config --disable CONFIG_NET_VENDOR_VIA
./scripts/config --disable CONFIG_NET_VENDOR_WIZNET

# Old laptop-specific vendor drivers (Fujitsu, Panasonic, Sony, Toshiba, etc.)
./scripts/config --disable CONFIG_FUJITSU_LAPTOP
./scripts/config --disable CONFIG_PANASONIC_LAPTOP
./scripts/config --disable CONFIG_SONY_LAPTOP
./scripts/config --disable CONFIG_TOPSTAR_LAPTOP
./scripts/config --disable CONFIG_TOSHIBA_BT_RFKILL
./scripts/config --disable CONFIG_TOSHIBA_HAPS
./scripts/config --disable CONFIG_SAMSUNG_LAPTOP
./scripts/config --disable CONFIG_ACER_WIRELESS

# 9. Server EDAC, Accessibility & Industrial IO Framework (Massive module bloat)
./scripts/config --disable CONFIG_EDAC
./scripts/config --disable CONFIG_ACCESSIBILITY
./scripts/config --disable CONFIG_SPEAKUP
./scripts/config --disable CONFIG_IIO

# 10. Archaic Wi-Fi & Obscure Bluetooth (Keep modern Intel/Realtek/MediaTek/Atheros Wi-Fi & USB BT)
./scripts/config --disable CONFIG_B43
./scripts/config --disable CONFIG_B43LEGACY
./scripts/config --disable CONFIG_AIRO
./scripts/config --disable CONFIG_ATMEL
./scripts/config --disable CONFIG_RT2400PCI
./scripts/config --disable CONFIG_RT2500PCI
./scripts/config --disable CONFIG_MWIFIEX
./scripts/config --disable CONFIG_WL12XX
./scripts/config --disable CONFIG_WL18XX
./scripts/config --disable CONFIG_BT_MRVL
./scripts/config --disable CONFIG_BT_MTK
./scripts/config --disable CONFIG_BT_HCIBTSDIO

# 11. Archaic PCI Sound Cards (Keep Intel HDA, Realtek, HDMI & USB Audio)
./scripts/config --disable CONFIG_SND_EMU10K1
./scripts/config --disable CONFIG_SND_YMFPCI
./scripts/config --disable CONFIG_SND_TRIDENT
./scripts/config --disable CONFIG_SND_VIA82XX
./scripts/config --disable CONFIG_SND_CMIPCI
./scripts/config --disable CONFIG_SND_CS46XX
./scripts/config --disable CONFIG_SND_ENS1370
./scripts/config --disable CONFIG_SND_ENS1371
./scripts/config --disable CONFIG_SND_ES1938
./scripts/config --disable CONFIG_SND_ES1968
./scripts/config --disable CONFIG_SND_FM801
./scripts/config --disable CONFIG_SND_ICE1712
./scripts/config --disable CONFIG_SND_ICE1724
./scripts/config --disable CONFIG_SND_KORG1212
./scripts/config --disable CONFIG_SND_MIXART
./scripts/config --disable CONFIG_SND_NM256
./scripts/config --disable CONFIG_SND_RME32
./scripts/config --disable CONFIG_SND_RME96
./scripts/config --disable CONFIG_SND_RME9652
./scripts/config --disable CONFIG_SND_SONICVIBES
./scripts/config --disable CONFIG_SND_VX222

# 12. Obscure USB Serials (Keep FTDI, CP210x, CH341, PL2303, CDC-ACM Arduino/STM32/Pico)
./scripts/config --disable CONFIG_USB_SERIAL_GARMIN
./scripts/config --disable CONFIG_USB_SERIAL_NAVMAN
./scripts/config --disable CONFIG_USB_SERIAL_OMNINET
./scripts/config --disable CONFIG_USB_SERIAL_OPTICON
./scripts/config --disable CONFIG_USB_SERIAL_WHITEHEAT
./scripts/config --disable CONFIG_USB_SERIAL_DIGI_ACCELEPORT
./scripts/config --disable CONFIG_USB_SERIAL_CYPRESS_M8
./scripts/config --disable CONFIG_USB_SERIAL_EMPEG
./scripts/config --disable CONFIG_USB_SERIAL_IR
./scripts/config --disable CONFIG_USB_SERIAL_IPAQ
./scripts/config --disable CONFIG_USB_SERIAL_KEYSPAN
./scripts/config --disable CONFIG_USB_SERIAL_KLSI
./scripts/config --disable CONFIG_USB_SERIAL_KOBIL_SCT
./scripts/config --disable CONFIG_USB_SERIAL_MCT_U232
./scripts/config --disable CONFIG_USB_SERIAL_MOS7720
./scripts/config --disable CONFIG_USB_SERIAL_MOS7840
./scripts/config --disable CONFIG_USB_SERIAL_SAFE
./scripts/config --disable CONFIG_USB_SERIAL_SIERRAWIRELESS
./scripts/config --disable CONFIG_USB_SERIAL_SYMBOL
./scripts/config --disable CONFIG_USB_SERIAL_TI
./scripts/config --disable CONFIG_USB_SERIAL_VISOR
./scripts/config --disable CONFIG_USB_SERIAL_XIRCOM

# 13. Vendor-specific Obscure HID Drivers (Generic HID and Gamepads are kept)
./scripts/config --disable CONFIG_HID_A4TECH
./scripts/config --disable CONFIG_HID_ACRUX
./scripts/config --disable CONFIG_HID_APPLE
./scripts/config --disable CONFIG_HID_BELKIN
./scripts/config --disable CONFIG_HID_CHERRY
./scripts/config --disable CONFIG_HID_CHICONY
./scripts/config --disable CONFIG_HID_CYPRESS
./scripts/config --disable CONFIG_HID_DRAGONRISE
./scripts/config --disable CONFIG_HID_EMS_FF
./scripts/config --disable CONFIG_HID_ELECOM
./scripts/config --disable CONFIG_HID_EZKEY
./scripts/config --disable CONFIG_HID_HOLTEK
./scripts/config --disable CONFIG_HID_KEYTOUCH
./scripts/config --disable CONFIG_HID_KYE
./scripts/config --disable CONFIG_HID_UCLOGIC
./scripts/config --disable CONFIG_HID_WALTOP
./scripts/config --disable CONFIG_HID_GYRATION
./scripts/config --disable CONFIG_HID_TWINHAN
./scripts/config --disable CONFIG_HID_KENSINGTON
./scripts/config --disable CONFIG_HID_LCPOWER
./scripts/config --disable CONFIG_HID_LENOVO
./scripts/config --disable CONFIG_HID_MONTEREY
./scripts/config --disable CONFIG_HID_NTRIG
./scripts/config --disable CONFIG_HID_ORTEK
./scripts/config --disable CONFIG_HID_PANTHERLORD
./scripts/config --disable CONFIG_HID_PETALYNX
./scripts/config --disable CONFIG_HID_PICOLCD
./scripts/config --disable CONFIG_HID_PRIMAX
./scripts/config --disable CONFIG_HID_SAITEK
./scripts/config --disable CONFIG_HID_SAMSUNG
./scripts/config --disable CONFIG_HID_SPEEDLINK
./scripts/config --disable CONFIG_HID_STEELSERIES
./scripts/config --disable CONFIG_HID_SUNPLUS
./scripts/config --disable CONFIG_HID_GREENASIA
./scripts/config --disable CONFIG_HID_SMARTJOYPLUS
./scripts/config --disable CONFIG_HID_TIVO
./scripts/config --disable CONFIG_HID_TOPSEED
./scripts/config --disable CONFIG_HID_THRUSTMASTER
./scripts/config --disable CONFIG_HID_WACOM
./scripts/config --disable CONFIG_HID_WIIMOTE
./scripts/config --disable CONFIG_HID_ZEROPLUS
./scripts/config --disable CONFIG_HID_ZYDACRON

# 14. Ancient & Insecure Crypto Algorithms (Keep AES, SHA256/512, ChaCha20, Curve25519)
./scripts/config --disable CONFIG_CRYPTO_TWOFISH
./scripts/config --disable CONFIG_CRYPTO_SERPENT
./scripts/config --disable CONFIG_CRYPTO_CAST5
./scripts/config --disable CONFIG_CRYPTO_CAST6
./scripts/config --disable CONFIG_CRYPTO_BLOWFISH
./scripts/config --disable CONFIG_CRYPTO_CAMELLIA
./scripts/config --disable CONFIG_CRYPTO_ANUBIS
./scripts/config --disable CONFIG_CRYPTO_KHAZAD
./scripts/config --disable CONFIG_CRYPTO_SEED
./scripts/config --disable CONFIG_CRYPTO_TEA
./scripts/config --disable CONFIG_CRYPTO_ARC4
./scripts/config --disable CONFIG_CRYPTO_DES
./scripts/config --disable CONFIG_CRYPTO_MD4

# 15. Archaic Analog Video Capture (Keep USB UVC webcams)
./scripts/config --disable CONFIG_VIDEO_BT848
./scripts/config --disable CONFIG_VIDEO_BWQCAM
./scripts/config --disable CONFIG_VIDEO_CQCAM
./scripts/config --disable CONFIG_VIDEO_HEXIUM_GEMINI
./scripts/config --disable CONFIG_VIDEO_HEXIUM_ORION
./scripts/config --disable CONFIG_VIDEO_MXB
./scripts/config --disable CONFIG_VIDEO_SAA7146
./scripts/config --disable CONFIG_VIDEO_ZORAN

# 16. Archaic Network Protocols (Obscure ancient network layers)
./scripts/config --disable CONFIG_ATALK
./scripts/config --disable CONFIG_X25
./scripts/config --disable CONFIG_LAPB
./scripts/config --disable CONFIG_PHONET
./scripts/config --disable CONFIG_CAIF
./scripts/config --disable CONFIG_6LOWPAN
./scripts/config --disable CONFIG_RDS
./scripts/config --disable CONFIG_TIPC
./scripts/config --disable CONFIG_AF_RXRPC
./scripts/config --disable CONFIG_KCM
./scripts/config --disable CONFIG_L2TP

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

# Remove heavy debug info, locks and module signing for production RT
./scripts/config --enable CONFIG_DEBUG_INFO_NONE
./scripts/config --disable CONFIG_DEBUG_INFO
./scripts/config --disable CONFIG_DEBUG_INFO_DWARF_TOOLCHAIN_DEFAULT
./scripts/config --disable CONFIG_DEBUG_INFO_DWARF4
./scripts/config --disable CONFIG_DEBUG_INFO_DWARF5
./scripts/config --disable CONFIG_DEBUG_INFO_BTF
./scripts/config --disable CONFIG_DEBUG_INFO_BTF_MODULES
./scripts/config --disable CONFIG_PROVE_LOCKING
./scripts/config --disable CONFIG_LOCKDEP
./scripts/config --disable CONFIG_DEBUG_ATOMIC_SLEEP
./scripts/config --disable CONFIG_PAGE_POISONING
./scripts/config --disable CONFIG_DEBUG_KMEMLEAK

# Disable Module Signing (Fixes build failures without private signing keys)
./scripts/config --disable CONFIG_MODULE_SIG
./scripts/config --disable CONFIG_MODULE_SIG_ALL
./scripts/config --disable CONFIG_MODULE_SIG_FORCE
./scripts/config --set-str CONFIG_MODULE_SIG_KEY ""
./scripts/config --set-str CONFIG_SYSTEM_TRUSTED_KEYS ""
./scripts/config --set-str CONFIG_SYSTEM_REVOCATION_KEYS ""

# Resolve configuration differences automatically
make olddefconfig > /dev/null

# 5. Build Debian packages with ccache acceleration & parallel compression
# Enable ccache in PATH
if command -v ccache >/dev/null 2>&1; then
    export PATH="/usr/lib/ccache:$PATH"
    export CC="ccache gcc"
    export HOSTCC="ccache gcc"
    echo "ccache enabled for ultra-fast compilation."
fi

# Multi-threaded compression & skip documentation
export ZSTD_NBTHREADS=0
export XZ_OPT="-T0"
export DEB_BUILD_OPTIONS="nodocs"
export DEB_BUILD_PROFILES="nodocs"
export INSTALL_MOD_STRIP=1

JOBS=$(( $(nproc) + 2 ))
echo "Compiling with $JOBS parallel jobs..."

make -j${JOBS} bindeb-pkg DPKG_FLAGS="-d"

# Ensure deb packages and cache are accessible
chmod -f a+rw ../*.deb || true
chmod -Rf a+rwX /root/.cache/ccache 2>/dev/null || true
ls -lh ../*.deb

echo "Build completed successfully."
