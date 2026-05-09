# nixos-flake-cockpit-nas

A reusable NixOS flake module for deploying Cockpit with NAS-focused plugins and configurations.

## Features

- Pre-configured Cockpit with fixes for storage/zfs modules (removed `path-exists` checks, fixed Python shebangs)
- Includes 45Drives Cockpit plugins:
  - `cockpit-file-sharing`: Manage Samba/NFS shares via UI
  - `cockpit-identities`: User/group management
- Integrated Samba with `include = registry` for Cockpit File Sharing
- Podman integration via `cockpit-podman`
- Optional ZFS support with `cockpit-zfs` (via `enableZfs` option)
- Optional VM management with `cockpit-machines` and `libvirtd` (via `enableMachines` option)
- Optional Tailscale integration with `cockpit-tailscale` (via `enableTailscale` option)
- udisks2 configuration for storage management
- Pre-configured systemd services for Cockpit and Samba

## Usage

### As a Flake Input

Add to your `flake.nix` inputs:

```nix
inputs.cockpit-nas = {
  url = "github:Snockow6/nixos-flake-cockpit-nas";
  inputs.nixpkgs.follows = "nixpkgs";
  inputs.nixpkgs-unstable.follows = "nixpkgs-unstable";
};
```

Update your lock file:

```bash
nix flake update
```

### Import the Module

Add to your NixOS configuration imports:

```nix
{ config, pkgs, inputs, ... }:
{
  imports = [ inputs.cockpit-nas.nixosModules.cockpit-nas ];

  # Optional: Configure allowed Cockpit connection origins
  services.cockpit.origins = [
    "https://localhost:9090"
    "https://your-hostname:9090"
    "https://your-ip:9090"
  ];

   # Optional: Enable VM management with cockpit-machines and libvirt
   services.cockpit.enableMachines = true;

   # Optional: Enable ZFS management with cockpit-zfs
   services.cockpit.enableZfs = true;

   # Optional: Enable Tailscale integration with cockpit-tailscale
   services.cockpit.enableTailscale = true;
}
```

## Packages

Available via `self.packages.${system}`:

- `cockpit-file-sharing`: 45Drives plugin for managing Samba/NFS/iSCSI/S3 storage
- `cockpit-identities`: 45Drives plugin for user and group management
- `cockpit-tailscale`: 45Drives plugin for managing Tailscale nodes

## Module Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `services.cockpit.origins` | `listOf str` | `["https://localhost:9090"]` | Allowed origins for Cockpit web connections |
| `services.cockpit.enableMachines` | `bool` | `false` | Enable Cockpit Machines and libvirt for VM management |
| `services.cockpit.enableZfs` | `bool` | `false` | Enable Cockpit ZFS plugin for ZFS pool management |
| `services.cockpit.enableTailscale` | `bool` | `false` | Enable Cockpit Tailscale plugin for Tailscale node management |

## Deploying to Remote Machine

A deploy script `deploy.sh` is included for deploying to the `nixostesting` remote machine.

### Prerequisites

- SSH access to `nixostesting` machine
- Remote machine runs NixOS with flakes enabled

### Usage

```bash
# Build and deploy (activate on remote)
./deploy.sh

# Build only (result in ./result)
./deploy.sh --build

# Build and copy to remote store (don't activate)
./deploy.sh --copy
```

### Configuration

The `nixostesting` configuration is defined in `flake.nix` under `nixosConfigurations.nixostesting`. To customize for your setup, edit:

- `networking.hostName`: Hostname of the target machine
- `boot.loader.grub.device`: Boot device for GRUB
- `fileSystems."/"`: Root filesystem configuration
- `services.cockpit.origins`: Allowed origins for Cockpit access

## Building

Build the system configuration for `nixostesting`:

```bash
nix build .#nixosConfigurations.nixostesting
```

Or use the deploy script:

```bash
./deploy.sh --build
```

## License

This project is licensed under the MIT License (see [LICENSE](LICENSE) for details).
