{
  description = "NixOS Cockpit module for NAS with custom packages, reusable as a flake input";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs, nixpkgs-unstable }:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = f: nixpkgs.lib.genAttrs supportedSystems (system: f system);
    in
    {
      packages = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          cockpit-file-sharing = pkgs.callPackage ./pkgs/cockpit-file-sharing.nix {};
          cockpit-identities = pkgs.callPackage ./pkgs/cockpit-identities.nix {};
          cockpit-tailscale = pkgs.callPackage ./pkgs/cockpit-tailscale.nix {};
          cockpit-navigator = pkgs.callPackage ./pkgs/cockpit-navigator.nix {};
        }
      );

      nixosModules.cockpit-nas = { config, pkgs, lib, inputs, ... }:
        let
          unstable = nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system};
          cfg = config.services.cockpit;
          cockpit-fixed = unstable.cockpit.overrideAttrs (old: {
            postInstall = (old.postInstall or "") + ''
              if [ -f $out/share/cockpit/storaged/manifest.json ]; then
                mv $out/share/cockpit/storaged/manifest.json $out/share/cockpit/storaged/manifest.json.bak
                grep -v "path-exists" $out/share/cockpit/storaged/manifest.json.bak > $out/share/cockpit/storaged/manifest.json
                rm $out/share/cockpit/storaged/manifest.json.bak
              fi
              for f in $out/share/cockpit/storaged/btrfs-tool; do
                if [ -f "$f" ]; then
                  sed -i '1s|^/#!|#!/|' "$f"
                fi
              done
            '';
          });
          cockpit-zfs-fixed = unstable.cockpit-zfs.overrideAttrs (old: {
            postInstall = (old.postInstall or "") + ''
              if [ -f $out/share/cockpit/zfs/manifest.json ]; then
                mv $out/share/cockpit/zfs/manifest.json $out/share/cockpit/zfs/manifest.json.bak
                grep -v "path-exists" $out/share/cockpit/zfs/manifest.json.bak > $out/share/cockpit/zfs/manifest.json
                rm $out/share/cockpit/zfs/manifest.json.bak
              fi
            '';
          });
        in
        {
options.services.cockpit.origins = lib.mkOption {
  type = lib.types.listOf lib.types.str;
  default = [ "https://localhost:9090" ];
  description = "Allowed origins for Cockpit connections";
};

options.services.cockpit.enableMachines = lib.mkOption {
  type = lib.types.bool;
  default = false;
  description = "Enable Cockpit Machines and libvirt for VM management";
};

options.services.cockpit.enableZfs = lib.mkOption {
  type = lib.types.bool;
  default = false;
  description = "Enable Cockpit ZFS plugin for ZFS pool management";
};

options.services.cockpit.enableTailscale = lib.mkOption {
  type = lib.types.bool;
  default = false;
  description = "Enable Cockpit Tailscale plugin for Tailscale node management";
};

options.services.cockpit.enableNavigator = lib.mkOption {
  type = lib.types.bool;
  default = false;
  description = "Enable Cockpit Navigator plugin for disk usage visualization";
};

          config = {
            services.samba.enable = true;
            services.samba.settings.global = {
              "include" = "registry";
            };

            services.cockpit = {
              enable = true;
              openFirewall = true;
              port = 9090;
              package = cockpit-fixed;
              settings = {
                WebService = {
                  LoginTo = false;
                  Origins = lib.mkForce (lib.concatStringsSep " " cfg.origins);
                  CockpitCSP = "default-src 'self' 'unsafe-inline' 'unsafe-eval'; script-src-elem 'self' 'unsafe-inline'; connect-src 'self' ws: wss:; form-action 'none'; frame-ancestors 'self';";
                };
              };
            };

            systemd.services.cockpit.serviceConfig.PrivateDevices = false;
            systemd.services.cockpit.path = lib.mkIf cfg.enableMachines [ pkgs.virt-manager ];
            systemd.services."cockpit-wsinstance-https@".serviceConfig.PrivateDevices = false;
            systemd.services."cockpit-wsinstance-http@".serviceConfig.PrivateDevices = false;

            services.udisks2.enable = true;

            environment.etc."udisks2/udisks2.conf" = lib.mkForce {
              text = ''
                [udisks2]
                modules=
              '';
            };

            virtualisation.podman = {
              enable = true;
              autoPrune.enable = true;
            };

            virtualisation.libvirtd = lib.mkIf cfg.enableMachines {
              enable = true;
              qemu.swtpm.enable = true;
            };

            services.dbus.packages = lib.mkIf cfg.enableMachines [ pkgs.libvirt-dbus ];

            systemd.packages = lib.mkIf cfg.enableMachines [ pkgs.libvirt-dbus ];

            # Create static libvirtdbus user so D-Bus can resolve it at startup
            # (DynamicUser=yes would create it transiently, but D-Bus loads config
            # before the service starts and needs the user to exist for policy checks)
            users.groups = lib.mkIf cfg.enableMachines {
              libvirt = {};
              libvirtdbus = {};
            };

            users.users = lib.mkIf cfg.enableMachines {
              libvirtdbus = {
                isSystemUser = true;
                group = "libvirtdbus";
                extraGroups = [ "qemu-libvirtd" "libvirtd" "libvirt" ];
                description = "Libvirt D-Bus daemon user";
              };
            };

            environment.systemPackages = with pkgs;
              [
                cockpit-fixed
                unstable.cockpit-podman
                self.packages.${pkgs.stdenv.hostPlatform.system}.cockpit-file-sharing
              ]
              ++ lib.optional cfg.enableMachines unstable.cockpit-machines
              ++ lib.optionals cfg.enableMachines [ qemu virt-manager ]
              ++ lib.optional cfg.enableZfs cockpit-zfs-fixed
              ++ lib.optional cfg.enableZfs (python312.withPackages (ps: [ ps.py-libzfs ]))
              ++ lib.optional cfg.enableZfs zfs
              ++ lib.optional cfg.enableTailscale self.packages.${pkgs.stdenv.hostPlatform.system}.cockpit-tailscale
              ++ lib.optional cfg.enableNavigator self.packages.${pkgs.stdenv.hostPlatform.system}.cockpit-navigator;

            systemd.tmpfiles.rules = [
              "L+ /var/lib/cockpit/file-sharing - - - - ${self.packages.${pkgs.stdenv.hostPlatform.system}.cockpit-file-sharing}/share/cockpit/file-sharing"
              "L+ /var/lib/cockpit/identities - - - - ${self.packages.${pkgs.stdenv.hostPlatform.system}.cockpit-identities}/share/cockpit/identities"
            ] ++ lib.optional cfg.enableMachines "L+ /var/lib/cockpit/machines - - - - ${unstable.cockpit-machines}/share/cockpit/machines"
              ++ lib.optional cfg.enableZfs "L+ /var/lib/cockpit/zfs - - - - ${cockpit-zfs-fixed}/share/cockpit/zfs"
              ++ lib.optional cfg.enableZfs "L+ /usr/local/bin/python3 - - - - ${pkgs.python312.withPackages (ps: [ ps.py-libzfs ])}/bin/python3"
              ++ lib.optional cfg.enableTailscale "L+ /var/lib/cockpit/tailscale - - - - ${self.packages.${pkgs.stdenv.hostPlatform.system}.cockpit-tailscale}/share/cockpit/tailscale"
              ++ lib.optional cfg.enableNavigator "L+ /var/lib/cockpit/navigator - - - - ${self.packages.${pkgs.stdenv.hostPlatform.system}.cockpit-navigator}/share/cockpit/navigator"
              ++ lib.optional cfg.enableNavigator "d /usr/share/cockpit 0755 root root -"
              ++ lib.optional cfg.enableNavigator "L+ /usr/share/cockpit/navigator - - - - /var/lib/cockpit/navigator";
          };
        };

      nixosConfigurations.nixostesting = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          self.nixosModules.cockpit-nas
          {
            system.stateVersion = "25.11";
            nixpkgs.config.allowUnfree = true;
            networking.hostName = "nixostesting";
            services.cockpit.origins = [
              "https://localhost:9090"
              "https://nixostesting:9090"
            ];
            boot.loader.grub.enable = true;
            boot.loader.grub.device = "/dev/sda";
            fileSystems."/" = { device = "/dev/sda"; fsType = "ext4"; };
          }
        ];
      };
    };
}
