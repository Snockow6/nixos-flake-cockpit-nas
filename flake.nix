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
  description = "Enable Cockpit Tailscale plugin for Tailscale management";
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
                };
              };
            };

            services.netdata = {
              enable = true;
              package = pkgs.netdata.override { withCloudUi = true; };
              claimTokenFile = "/etc/netdata/claim-token";
            };

            environment.etc."netdata/claim-token" = {
              text = "E3Np7G2sRTKqupEsnLGrEkzILMfLRkKaAAyA5fR_oBSsRLeoOzPjqurBNqC2-G-8vkTU57Hk6YEq5hk5WY1zcX0EiFDX7fXeY22_H8GAeXx_NHENEyR3On1ZtYLb-0k3hhU64GA";
              mode = "0400";
              user = "netdata";
              group = "netdata";
            };

            networking.firewall.allowedTCPPorts = [ 19999 ];

            systemd.services.cockpit.serviceConfig.PrivateDevices = false;
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

            virtualisation.libvirtd.enable = lib.mkIf cfg.enableMachines true;

            services.dbus.packages = lib.mkIf cfg.enableMachines [ pkgs.libvirt-dbus ];

            systemd.packages = lib.mkIf cfg.enableMachines [ pkgs.libvirt-dbus ];

            environment.systemPackages = with pkgs;
              [
                cockpit-fixed
                unstable.cockpit-podman
                self.packages.${pkgs.stdenv.hostPlatform.system}.cockpit-file-sharing
              ]
              ++ lib.optional cfg.enableMachines unstable.cockpit-machines
              ++ lib.optional cfg.enableZfs cockpit-zfs-fixed
              ++ lib.optional cfg.enableZfs (python312.withPackages (ps: [ ps.py-libzfs ]))
              ++ lib.optional cfg.enableZfs zfs
              ++ lib.optional cfg.enableTailscale unstable.cockpit-tailscale;

            systemd.tmpfiles.rules = [
              "L+ /var/lib/cockpit/file-sharing - - - - ${self.packages.${pkgs.stdenv.hostPlatform.system}.cockpit-file-sharing}/share/cockpit/file-sharing"
              "L+ /var/lib/cockpit/identities - - - - ${self.packages.${pkgs.stdenv.hostPlatform.system}.cockpit-identities}/share/cockpit/identities"
            ] ++ lib.optional cfg.enableMachines "L+ /var/lib/cockpit/machines - - - - ${unstable.cockpit-machines}/share/cockpit/machines"
              ++ lib.optional cfg.enableZfs "L+ /var/lib/cockpit/zfs - - - - ${cockpit-zfs-fixed}/share/cockpit/zfs"
              ++ lib.optional cfg.enableZfs "L+ /usr/local/bin/python3 - - - - ${pkgs.python312.withPackages (ps: [ ps.py-libzfs ])}/bin/python3"
              ++ lib.optional cfg.enableTailscale "L+ /var/lib/cockpit/tailscale - - - - ${unstable.cockpit-tailscale}/share/cockpit/tailscale";
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
