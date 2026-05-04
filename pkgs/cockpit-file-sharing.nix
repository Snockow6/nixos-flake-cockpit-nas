{ lib, stdenv, dpkg, fetchurl }:

stdenv.mkDerivation rec {
  pname = "cockpit-file-sharing";
  version = "4.5.6-1";

  src = fetchurl {
    url = "https://github.com/45Drives/cockpit-file-sharing/releases/download/v${version}/cockpit-file-sharing_${version}jammy_all.deb";
    hash = "sha256-ViTdhiCmqwuBvAfzT8hr2kqZqyWkV9OZ9FEPD10ajF8=";
  };

  nativeBuildInputs = [ dpkg ];

  unpackPhase = ''
    dpkg-deb -x $src .
  '';

  installPhase = ''
    mkdir -p $out/share/cockpit
    cp -r usr/share/cockpit/file-sharing $out/share/cockpit/
  '';

  meta = with lib; {
    description = "Cockpit plugin for managing Samba, NFS, iSCSI, and S3 storage services";
    homepage = "https://github.com/45Drives/cockpit-file-sharing";
    license = licenses.gpl3Only;
    platforms = platforms.linux;
    maintainers = [];
  };
}
