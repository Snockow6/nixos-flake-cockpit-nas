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
          services.samba.enable = true;

          services.cockpit = {
            enable = true;
            openFirewall = true;
            port = 9090;
            package = cockpit-fixed;
            settings = {
              WebService = {
                LoginTo = false;
              };
            };
          };

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

          environment.systemPackages = with pkgs; [
            cockpit-fixed
            unstable.cockpit-podman
            self.packages.${pkgs.stdenv.hostPlatform.system}.cockpit-file-sharing
            cockpit-zfs-fixed
            (python312.withPackages (ps: [ ps.py-libzfs ]))
            zfs
          ];

          systemd.tmpfiles.rules = [
            "L+ /var/lib/cockpit/file-sharing - - - - ${self.packages.${pkgs.stdenv.hostPlatform.system}.cockpit-file-sharing}/share/cockpit/file-sharing"
            "L+ /var/lib/cockpit/zfs - - - - ${cockpit-zfs-fixed}/share/cockpit/zfs"
            "L+ /usr/local/bin/python3 - - - - ${pkgs.python312.withPackages (ps: [ ps.py-libzfs ])}/bin/python3"
          ];
        }
      );

      nixosConfigurations.test-vm = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          self.nixosModules.cockpit-nas
        ];
      };
    };
}
