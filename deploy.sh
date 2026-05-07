#!/usr/bin/env bash
set -euo pipefail

# Deploy script for nixostesting
# Usage: ./deploy.sh [--build] [--copy] [--switch]

TARGET_HOST="nixostesting"
FLAKE_CONFIG=".#nixostesting"

BUILD_ONLY=false
COPY_ONLY=false
SWITCH=true

for arg in "$@"; do
  case $arg in
    --build)
      BUILD_ONLY=true
      SWITCH=false
      ;;
    --copy)
      COPY_ONLY=true
      SWITCH=false
      ;;
    --help|-h)
      echo "Usage: $0 [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --build    Only build the system, don't deploy"
      echo "  --copy     Build and copy to store, don't activate"
      echo "  --switch   Build and activate (default)"
      echo "  --help     Show this help message"
      exit 0
      ;;
  esac
done

if [ "$BUILD_ONLY" = true ]; then
  echo "Building configuration for $TARGET_HOST..."
  nixos-rebuild build --flake "$FLAKE_CONFIG"
  echo "Build complete. Result in ./result"
elif [ "$COPY_ONLY" = true ]; then
  echo "Building and copying to $TARGET_HOST..."
  nixos-rebuild build --flake "$FLAKE_CONFIG"
  nix copy ./result --to "ssh://$TARGET_HOST"
  echo "Configuration copied to $TARGET_HOST"
else
  echo "Deploying to $TARGET_HOST..."
  nixos-rebuild switch --flake "$FLAKE_CONFIG" --target-host "$TARGET_HOST"
  echo "Deployment complete!"
fi
