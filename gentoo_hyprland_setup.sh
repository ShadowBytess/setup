#!/usr/bin/env bash
# Gentoo Configuration Script for Ryzen 5 4500 & RX 5500 XT (Hyprland)

set -e

echo "Setting up make.conf optimizations..."
cat << 'EOF' > /etc/portage/make.conf
COMMON_FLAGS="-O2 -march=znver2 -pipe"
CFLAGS="${COMMON_FLAGS}"
CXXFLAGS="${COMMON_FLAGS}"

MAKEOPTS="-j12"
VIDEO_CARDS="amdgpu radeonsi"
INPUT_DEVICES="libinput"

USE="wayland seatd pipewire elogind dbus udev amdgpu vulkan -X -gnome -kde"
ACCEPT_LICENSE="*"
EOF

echo "Setting up basic package rules..."
mkdir -p /etc/portage/package.use
echo "media-libs/mesa vulkan" > /etc/portage/package.use/video

echo "Done! Run emerge --sync to proceed."
