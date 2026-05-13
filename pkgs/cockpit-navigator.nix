{ lib, stdenv, rpm, cpio, fetchurl }:

stdenv.mkDerivation rec {
  pname = "cockpit-navigator";
  version = "0.6.1";

  src = fetchurl {
    url = "https://github.com/45Drives/cockpit-navigator/releases/download/v${version}/cockpit-navigator-${version}-1.el9.noarch.rpm";
    hash = "sha256-3Kr1Q7h/fXgV/3OpO1ivq+wwlBLDRdaN6YR6kfPkFIo=";
  };

  nativeBuildInputs = [ rpm cpio ];

  unpackPhase = ''
    rpm2cpio $src | cpio -idmv
  '';

  installPhase = ''
    mkdir -p $out/share/cockpit
    cp -r usr/share/cockpit/navigator $out/share/cockpit/
  '';

  postFixup = ''
    patchShebangs $out/share/cockpit/navigator/scripts
  '';

  meta = with lib; {
    description = "Cockpit application for visual disk usage management";
    homepage = "https://github.com/45Drives/cockpit-navigator";
    license = licenses.gpl3Only;
    platforms = platforms.linux;
    maintainers = [];
  };
}
