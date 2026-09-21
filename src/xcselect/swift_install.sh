#!/bin/bash
# This file is part of Darling / VibeDarling.
# 
# Installer for Swift Darwin Toolchain (on demand).
# Downloads and extracts the official Swift release from swift.org
# and configures xcrun / DarlingCLT and runtime libraries.

set -e

SWIFT_VERSION="${SWIFT_VERSION:-6.3.3}"
TOOLCHAIN_DIR="/Library/Developer/Toolchains/swift.xctoolchain"
CLT_DIR="/Library/Developer/DarlingCLT/usr/bin"
SWIFT_LIB_DIR="/usr/lib/swift"

echo "=================================================="
echo "  VibeDarling Swift Toolchain Installer (On-Demand)"
echo "=================================================="
echo "Target version: Swift ${SWIFT_VERSION}"

# Check if already installed
if [ -x "${TOOLCHAIN_DIR}/usr/bin/swift" ] && [ "${FORCE_INSTALL}" != "1" ]; then
    echo "Swift toolchain is already installed at: ${TOOLCHAIN_DIR}"
    echo "Installed version:"
    "${TOOLCHAIN_DIR}/usr/bin/swift" --version 2>/dev/null || true
    exit 0
fi

# Ask confirmation if interactive and not forced
if [ -t 0 ] && [ "${FORCE_INSTALL}" != "1" ]; then
    read -r -p "Do you want to download and install Swift ${SWIFT_VERSION} toolchain? [Y/n] " answer
    case "$answer" in
        [nN][oO]|[nN])
            echo "Installation aborted by user."
            exit 1
            ;;
        *)
            ;;
    esac
fi

TEMP_DIR=$(mktemp -d /tmp/swift-install.XXXXXX)
cleanup() {
    rm -rf "${TEMP_DIR}"
}
trap cleanup EXIT

PKG_NAME="swift-${SWIFT_VERSION}-RELEASE-osx.pkg"
PKG_URL="https://download.swift.org/swift-${SWIFT_VERSION}-release/xcode/swift-${SWIFT_VERSION}-RELEASE/${PKG_NAME}"
PKG_FILE="${TEMP_DIR}/${PKG_NAME}"

# Known official release checksums from Swift.org
EXPECTED_SHA256=""
if [ "${SWIFT_VERSION}" = "6.3.3" ]; then
    EXPECTED_SHA256="ee82e57774d6650f94aa06302435d6f44a055b9411698db8ecb85d9a3bcc91d0"
fi

if [ -n "${SWIFT_PKG}" ] && [ -f "${SWIFT_PKG}" ]; then
    echo "Using provided local package: ${SWIFT_PKG}"
    PKG_FILE="${SWIFT_PKG}"
else
    echo "Downloading Swift toolchain from Swift.org..."
    echo "URL: ${PKG_URL}"
    if command -v curl >/dev/null 2>&1; then
        curl -L --progress-bar "${PKG_URL}" -o "${PKG_FILE}"
    elif command -v wget >/dev/null 2>&1; then
        wget --progress=bar "${PKG_URL}" -O "${PKG_FILE}"
    else
        echo "Error: neither curl nor wget found."
        exit 1
    fi
fi

if [ -n "${EXPECTED_SHA256}" ]; then
    echo "Verifying SHA-256 checksum..."
    CALCULATED_SHA256=""
    if command -v sha256sum >/dev/null 2>&1; then
        CALCULATED_SHA256=$(sha256sum "${PKG_FILE}" | awk '{print $1}')
    elif command -v shasum >/dev/null 2>&1; then
        CALCULATED_SHA256=$(shasum -a 256 "${PKG_FILE}" | awk '{print $1}')
    fi

    if [ -n "${CALCULATED_SHA256}" ]; then
        if [ "${CALCULATED_SHA256}" != "${EXPECTED_SHA256}" ]; then
            echo "Error: SHA-256 checksum mismatch!"
            echo "Expected:   ${EXPECTED_SHA256}"
            echo "Calculated: ${CALCULATED_SHA256}"
            exit 1
        fi
        echo "Checksum verified: OK"
    fi
fi

echo "Extracting package contents..."
EXTRACT_DIR="${TEMP_DIR}/extracted"
mkdir -p "${EXTRACT_DIR}"

if command -v xar >/dev/null 2>&1; then
    (cd "${EXTRACT_DIR}" && xar -xf "${PKG_FILE}")
elif command -v bsdtar >/dev/null 2>&1; then
    (cd "${EXTRACT_DIR}" && bsdtar -xf "${PKG_FILE}")
else
    echo "Error: neither xar nor bsdtar found for package extraction."
    exit 1
fi

PAYLOAD_FILE=$(find "${EXTRACT_DIR}" -name "Payload" -type f | head -n 1)
if [ -z "${PAYLOAD_FILE}" ] || [ ! -f "${PAYLOAD_FILE}" ]; then
    echo "Error: could not find package Payload inside ${PKG_NAME}."
    exit 1
fi

echo "Installing toolchain to ${TOOLCHAIN_DIR}..."
mkdir -p "${TOOLCHAIN_DIR}"

if command -v gunzip >/dev/null 2>&1 && command -v cpio >/dev/null 2>&1; then
    gunzip -dc "${PAYLOAD_FILE}" | (cd "${TOOLCHAIN_DIR}" && cpio -idm 2>/dev/null)
elif command -v bsdtar >/dev/null 2>&1; then
    bsdtar -xf "${PAYLOAD_FILE}" -C "${TOOLCHAIN_DIR}"
else
    echo "Error: cannot extract Payload (requires gunzip+cpio or bsdtar)."
    exit 1
fi

# Link toolchain executables into DarlingCLT so xcrun and PATH find them immediately
mkdir -p "${CLT_DIR}"
for tool in swift swiftc swift-build swift-package swift-test swift-run; do
    if [ -f "${TOOLCHAIN_DIR}/usr/bin/${tool}" ]; then
        ln -sf "${TOOLCHAIN_DIR}/usr/bin/${tool}" "${CLT_DIR}/${tool}"
        echo "Linked ${tool} -> ${CLT_DIR}/${tool}"
    fi
done

# Copy / update official universal runtime libraries into /usr/lib/swift
if [ -d "${TOOLCHAIN_DIR}/usr/lib/swift/macosx" ]; then
    mkdir -p "${SWIFT_LIB_DIR}"
    echo "Updating Swift runtime libraries in ${SWIFT_LIB_DIR}..."
    for dylib in "${TOOLCHAIN_DIR}/usr/lib/swift/macosx"/libswift*.dylib; do
        if [ -f "${dylib}" ] || [ -L "${dylib}" ]; then
            base=$(basename "${dylib}")
            cp -Pf "${dylib}" "${SWIFT_LIB_DIR}/${base}" 2>/dev/null || true
        fi
    done
fi

echo ""
echo "=================================================="
echo "  Swift toolchain installed successfully!"
echo "=================================================="
if [ -x "${TOOLCHAIN_DIR}/usr/bin/swift" ]; then
    "${TOOLCHAIN_DIR}/usr/bin/swift" --version || true
fi
