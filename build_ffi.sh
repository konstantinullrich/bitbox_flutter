#!/usr/bin/env bash
# Builds the Go dart:ffi bridge (go/ffi) as libbitbox.so for every Android ABI and places it
# in android/src/main/jniLibs/<abi>/, where the Flutter plugin packages it automatically.
#
# Usage: ./build_ffi.sh [abi ...]     (default: arm64-v8a armeabi-v7a x86_64)
#
# Requires Go and an Android NDK. The NDK is taken from ANDROID_NDK_HOME, ANDROID_NDK_ROOT
# or the newest version under $ANDROID_HOME/ndk.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
API_LEVEL=24
OUT_DIR="$ROOT/android/src/main/jniLibs"

find_ndk() {
  for candidate in "${ANDROID_NDK_HOME:-}" "${ANDROID_NDK_ROOT:-}"; do
    [[ -n "$candidate" && -d "$candidate" ]] && { echo "$candidate"; return; }
  done
  local sdk="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}}"
  local newest
  newest="$(ls -1 "$sdk/ndk" 2>/dev/null | sort -V | tail -1)"
  [[ -n "$newest" ]] && { echo "$sdk/ndk/$newest"; return; }
  echo "error: Android NDK not found; set ANDROID_NDK_HOME" >&2
  exit 1
}

NDK="$(find_ndk)"
case "$(uname -s)" in
  Darwin) HOST_TAG=darwin-x86_64 ;; # also used on Apple Silicon
  Linux) HOST_TAG=linux-x86_64 ;;
  *) echo "error: unsupported host $(uname -s)" >&2; exit 1 ;;
esac
TOOLCHAIN="$NDK/toolchains/llvm/prebuilt/$HOST_TAG/bin"
[[ -d "$TOOLCHAIN" ]] || { echo "error: no NDK toolchain at $TOOLCHAIN" >&2; exit 1; }

build_abi() {
  local abi="$1" goarch goarm="" cc
  case "$abi" in
    arm64-v8a)   goarch=arm64; cc=aarch64-linux-android$API_LEVEL-clang ;;
    armeabi-v7a) goarch=arm;   goarm=7; cc=armv7a-linux-androideabi$API_LEVEL-clang ;;
    x86_64)      goarch=amd64; cc=x86_64-linux-android$API_LEVEL-clang ;;
    x86)         goarch=386;   cc=i686-linux-android$API_LEVEL-clang ;;
    *) echo "error: unknown ABI $abi" >&2; exit 1 ;;
  esac

  echo "==> $abi"
  mkdir -p "$OUT_DIR/$abi"
  # 16 KB page alignment is required for apps targeting Android 15+ on Google Play.
  (
    cd "$ROOT/go"
    CGO_ENABLED=1 GOOS=android GOARCH="$goarch" GOARM="$goarm" CC="$TOOLCHAIN/$cc" \
      go build -buildmode=c-shared -trimpath \
      -ldflags "-s -w -extldflags=-Wl,-z,max-page-size=16384" \
      -o "$OUT_DIR/$abi/libbitbox.so" ./ffi
  )
  # The generated header is identical for every ABI; keep one copy next to bridge.h for ffigen.
  mv "$OUT_DIR/$abi/libbitbox.h" "$ROOT/go/ffi/libbitbox.h"
}

ABIS=("$@")
[[ ${#ABIS[@]} -eq 0 ]] && ABIS=(arm64-v8a armeabi-v7a x86_64)

echo "Using NDK $NDK (API $API_LEVEL)"
for abi in "${ABIS[@]}"; do
  build_abi "$abi"
done
echo "Done: $OUT_DIR"
