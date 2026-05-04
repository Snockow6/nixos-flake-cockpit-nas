{ lib, stdenv, dpkg, fetchurl }:

stdenv.mkDerivation rec {
  pname = "cockpit-identities";
  version = "0.1.12-1";

  src = fetchurl {
    url = "https://github.com/45Drives/cockpit-identities/releases/download/v0.1.12/cockpit-identities_${version}_focal_all.deb";
    hash = "sha256-1NVm3bO3EjsYW5q5COVytpWVP0MfM+8WxZLqnJVZVc=";
  };

  nativeBuildInputs = [ dpkg ];

  unpackPhase = ''
    dpkg-deb -x $src .
  '';

  installPhase = ''
    mkdir -p $out/share/cockpit
    cp -r usr/share/cockpit/identities $out/share/cockpit/
  '';

  meta = with lib; {
    description = "User and group management plugin for Cockpit";
    homepage = "https://github.com/45Drives/cockpit-identities";
    license = licenses.gpl3Only;
    platforms = platforms.linux;
    maintainers = [];
  };
}
