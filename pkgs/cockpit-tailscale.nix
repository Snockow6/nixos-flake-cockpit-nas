{ lib, buildNpmPackage, fetchzip }:

buildNpmPackage rec {
  pname = "cockpit-tailscale";
  version = "0.0.6";

  src = fetchzip {
    url = "https://github.com/gbraad-cockpit/cockpit-tailscale/archive/refs/tags/v${version}.tar.gz";
    sha256 = "q6CjEBoVAlYGMvdQ9IqPMNFlb6tyIGZ5dGq3mKMF2aA=";
  };

  npmDepsHash = "sha256-Q9RZcFh2t3WnzKC7/WM2E77iEQN6oZ+xwIMYm/gFL3s=";

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
