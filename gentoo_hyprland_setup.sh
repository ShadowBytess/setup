#!/bin/bash
# ==========================================================================
# GENTOO AUTOMATED INSTALLER - RYZEN 5 4500 / RX 5500 XT / HYPRLAND / FISH
# ==========================================================================
set -e

# --- CONFIGURATION (Change /dev/nvme0n1 if using a SATA SSD like /dev/sda) ---
DRIVE="/dev/nvme0n1"
EFI_PART="${DRIVE}p1"
ROOT_PART="${DRIVE}p2"

echo "====> [1/9] Partitioning and Formatting Disk: ${DRIVE}..."
parted -s "${DRIVE}" mklabel gpt
parted -s "${DRIVE}" mkpart primary fat32 1MiB 513MiB
parted -s "${DRIVE}" set 1 esp on
parted -s "${DRIVE}" mkpart primary ext4 513MiB 100%

mkfs.vfat -F 32 "${EFI_PART}"
mkfs.ext4 -F "${ROOT_PART}"

echo "====> [2/9] Mounting Filesystems..."
mkdir -p /mnt/gentoo
mount "${ROOT_PART}" /mnt/gentoo
mkdir -p /mnt/gentoo/boot/efi
mount "${EFI_PART}" /mnt/gentoo/boot/efi

echo "====> [3/9] Downloading and Extracting Stage3 (systemd)..."
cd /mnt/gentoo
# Automatically grabs the latest systemd desktop stage3 profile
STAGE3_URL=$(wget -qO- https://leaseweb.com | grep -oP 'stage3-amd64-desktop-systemd-\d{8}T\d{6}Z\.tar\.xz' | head -n1)
wget "https://leaseweb.com${STAGE3_URL}"
tar xpvf stage3-*.tar.xz --xattrs-include='*.*' --numeric-owner
rm stage3-*.tar.xz

echo "====> [4/9] Tuning hardware configurations in make.conf..."
cat <<EOF > /mnt/gentoo/etc/portage/make.conf
# Ryzen 5 4500 (Zen 2) Optimization Flags
COMMON_FLAGS="-O2 -march=znver2 -pipe"
CFLAGS="\${COMMON_FLAGS}"
CXXFLAGS="\${COMMON_FLAGS}"
FCFLAGS="\${COMMON_FLAGS}"
FFLAGS="\${COMMON_FLAGS}"

# Maximize Ryzen 5 4500 (6 Cores / 12 Threads) Compilation Power
MAKEOPTS="-j12"

# Pure Wayland & Minimal System Settings
USE="wayland seatd pipewire elogind sound-server dbus policykit -X -gnome -kde -plasma"

# RX 5500 XT Drivers & OpenCL Pipeline
VIDEO_CARDS="amdgpu radeonsi"

ACCEPT_LICENSE="*"
GRUB_PLATFORMS="efi-64"
EOF

echo "====> [5/9] Chrooting into System Environment..."
cp --dereference /etc/resolv.conf /mnt/gentoo/etc/
mount --make-rslave /mnt/gentoo
mount --types proc /proc /mnt/gentoo/proc
mount --rbind /sys /mnt/gentoo/sys
mount --make-rslave /mnt/gentoo/sys
mount --rbind /dev /mnt/gentoo/dev
mount --make-rslave /mnt/gentoo/dev
mount --bind /run /mnt/gentoo/run
mount --make-private /mnt/gentoo/run

# --- START INTERNAL CHROOT SCRIPT ---
chroot /mnt/gentoo /bin/bash <<'EOF'
source /etc/profile
export PS1="(chroot) $PS1"

echo "====> [6/9] Syncing Portage database..."
emerge-webrsync

echo "====> [7/9] Installing Hardware Firmware & Distribution Kernel..."
# Firmware is critical for your RX 5500 XT GPU to boot into a graphical interface
emerge sys-kernel/linux-firmware
emerge sys-kernel/gentoo-kernel-bin

echo "====> [8/9] Installing System Utilities, Hyprland & Fish..."
# Set globally acceptable license acceptances for dependencies
echo "gui-wm/hyprland ~amd64" >> /etc/portage/package.accept_keywords
echo "gui-libs/aquamarine ~amd64" >> /etc/portage/package.accept_keywords

emerge app-shells/fish gui-wm/hyprland sys-boot/grub

echo "====> [9/9] Establishing Shells, System Settings, and Boot..."
# Configure Fish globally and set it as the root system shell default
echo "/bin/fish" >> /etc/shells
chsh -s /bin/fish root

# Writing basic file definitions
cat <<FSTAB > /etc/fstab
${EFI_PART}   /boot/efi   vfat   defaults   0 2
${ROOT_PART}  /           ext4   noatime    0 1
FSTAB

# Installing and deploying GRUB Bootloader
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=Gentoo
grub-mkconfig -o /boot/grub/grub.cfg

echo "=========================================================================="
echo " BASE SYSTEM INSTALLED SUCCESSFULLY WITH FISH AND HYPRLAND!"
echo " Please type 'passwd' right now to establish a root terminal password,"
echo " then type 'exit' and reboot your computer."
echo "=========================================================================="
EOF
