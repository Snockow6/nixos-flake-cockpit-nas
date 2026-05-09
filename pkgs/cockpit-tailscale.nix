{ lib, buildNpmPackage, fetchzip, nodejs }:

buildNpmPackage rec {
  pname = "cockpit-tailscale";
  version = "0.0.6";

  src = fetchzip {
    url = "https://github.com/gbraad-cockpit/cockpit-tailscale/archive/refs/tags/v${version}.tar.gz";
    sha256 = "7eZXs/IhhD190LnhGO0i87YZBifG94OkdY+Zlb5xFAI=";
  };

  nativeBuildInputs = [ nodejs ];

  postPatch = ''
    npm install --package-lock-only
  '';

  npmDepsHash = lib.fakeHash;

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
