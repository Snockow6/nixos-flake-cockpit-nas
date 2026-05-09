{ lib, stdenv, rpm, cpio, fetchurl }:

stdenv.mkDerivation rec {
  pname = "cockpit-tailscale";
  version = "0.0.6";

  src = fetchurl {
    url = "https://github.com/gbraad-cockpit/cockpit-tailscale/releases/download/v${version}/cockpit-tailscale-v${version}-1.fc38.noarch.rpm";
    hash = "sha256-eed3BFnYMTcTAYf6B1+0RMTEm1LCoiiwlGMr+ABtAqE=";
  };

  nativeBuildInputs = [ rpm cpio ];

  unpackPhase = ''
    rpm2cpio $src | cpio -idmv
  '';

  installPhase = ''
    mkdir -p $out/share/cockpit
    cp -r usr/share/cockpit/tailscale $out/share/cockpit/
  '';

  meta = with lib; {
    description = "Cockpit application to manage Tailscale";
    homepage = "https://github.com/gbraad-cockpit/cockpit-tailscale";
    license = licenses.lgpl21Only;
    platforms = platforms.linux;
    maintainers = [];
  };
}
