# nixos-flake-cockpit-nas

A reusable NixOS flake module for deploying Cockpit with NAS-focused plugins and configurations.

## Features

- Pre-configured Cockpit with fixes for storage/zfs modules (removed `path-exists` checks, fixed Python shebangs)
- Includes 45Drives Cockpit plugins:
  - `cockpit-file-sharing`: Manage Samba/NFS shares via UI
  - `cockpit-identities`: User/group management
- Integrated Samba with `include = registry` for Cockpit File Sharing
- Podman integration via `cockpit-podman`
- ZFS support with `cockpit-zfs`
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
}
```

## Packages

Available via `self.packages.${system}`:

- `cockpit-file-sharing`: 45Drives plugin for managing Samba/NFS/iSCSI/S3 storage
- `cockpit-identities`: 45Drives plugin for user and group management

## Module Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `services.cockpit.origins` | `listOf str` | `["https://localhost:9090"]` | Allowed origins for Cockpit web connections |

## Building

Test the module with the included test VM configuration:

```bash
nix build .#nixosConfigurations.test-vm
```

## License

This project is licensed under the MIT License (see [LICENSE](LICENSE) for details).
