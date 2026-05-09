{ lib, stdenv, fetchzip, nodejs, npmBuildHook, python3 }:

stdenv.mkDerivation rec {
  pname = "cockpit-tailscale";
  version = "0.0.6";

  src = fetchzip {
    url = "https://github.com/gbraad-cockpit/cockpit-tailscale/archive/refs/tags/v${version}.tar.gz";
    hash = "sha256-q6CjEBoVAlYGMvdQ9IqPMNFlb6tyIGZ5dGq3mKMF2aA=";
  };

  nativeBuildInputs = [ nodejs npmBuildHook python3 ];

  installPhase = ''
    mkdir -p $out/share/cockpit/tailscale
    cp -r dist/* $out/share/cockpit/tailscale/
  '';

  meta = with lib; {
    description = "Cockpit application to manage Tailscale";
    homepage = "https://github.com/gbraad-cockpit/cockpit-tailscale";
    license = licenses.lgpl21Only;
    platforms = platforms.linux;
    maintainers = [];
  };
}
