# Installation Guide

Step-by-step guide to using `nixos-flake-cockpit-nas` in your NixOS setup.

## Prerequisites

- NixOS system with flakes enabled (`nix.settings.experimental-features = [ "nix-command" "flakes" ]`)
- Existing `flake.nix` for your system configuration
- `nixpkgs` and `nixpkgs-unstable` inputs in your flake (the module follows these inputs)

## Installation Steps

### 1. Add the Flake Input

Add the following to the `inputs` section of your system's `flake.nix`:

```nix
inputs.cockpit-nas = {
  url = "github:Snockow6/nixos-flake-cockpit-nas";
  inputs.nixpkgs.follows = "nixpkgs";
  inputs.nixpkgs-unstable.follows = "nixpkgs-unstable";
};
```

### 2. Update Flake Lock

Run the following to fetch the new input:

```bash
cd /path/to/your/nixos/flake
nix flake update
```

### 3. Import the Module

Add the module import to your NixOS configuration (e.g., `hosts/your-host/configuration.nix`):

```nix
{ config, pkgs, inputs, ... }:
{
  imports = [ inputs.cockpit-nas.nixosModules.cockpit-nas ];

  # Configure Cockpit origins for your network (replace with your actual hostnames/IPs)
  services.cockpit.origins = [
    "https://localhost:9090"
    "https://your-hostname:9090"
    "https://192.168.1.100:9090"  # Your system's IP
  ];
}
```

### 4. Rebuild and Switch

Deploy the new configuration:

```bash
sudo nixos-rebuild switch --flake .#your-hostname
```

### 5. Verify Installation

Check that Cockpit is running:

```bash
systemctl status cockpit.socket
```

You should see `Active: active (running)`.

Check Samba configuration for File Sharing support:

```bash
cat /etc/samba/smb.conf | grep "include = registry"
```

You should see `include = registry` in the `[global]` section (added automatically by the `samba-after-setup` service).

## Accessing Cockpit

Open your browser and navigate to:

```
https://<your-system-ip>:9090
```

Log in with your NixOS user credentials.

## Post-Installation

- **File Sharing**: Use the "File Sharing" tab in Cockpit to manage Samba shares
- **Podman**: Manage containers via the "Podman" tab
- **Storage**: View ZFS pools and disks under "Storage"
- **Users**: Manage users/groups via the "Identities" tab

## Troubleshooting

### "Connection failed" / TLS Errors

Ensure `services.cockpit.origins` includes the exact URL you're using to access Cockpit. The default only allows `localhost`.

### Samba "include = registry" Missing

The module includes a `samba-after-setup` service that adds this directive. Verify it ran:

```bash
systemctl status samba-after-setup
```

If it failed, run it manually:

```bash
sudo systemctl start samba-after-setup
```

### ZFS Features Not Working

Ensure:
1. ZFS is enabled in your system configuration
2. The `python312.withPackages (ps: [ ps.py-libzfs ])` package is available
3. `cockpit-zfs-fixed` is installed (included in the module)

### Podman Tab Missing

Verify `virtualisation.podman.enable = true` is set (automatically enabled by the module). Check Podman is running:

```bash
systemctl status podman
```
