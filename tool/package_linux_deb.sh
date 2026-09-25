#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != "Linux" || "$(uname -m)" != "x86_64" ]]; then
  printf '%s\n' 'O pacote Ubuntu requer Linux x86_64.' >&2
  exit 1
fi

version="${RELEASE_VERSION:-1.0.0}"
if [[ ! "$version" =~ ^[0-9]+([.][0-9]+)*([~+][A-Za-z0-9.-]+)?$ ]]; then
  printf '%s\n' 'A versão informada não é válida para um pacote Debian.' >&2
  exit 1
fi

root="$PWD/build/rtsp-view-deb"
package="$PWD/dist/rtsp-view_${version}_amd64.deb"
"$PWD/tool/package_linux.sh"
rm -rf "$root"
mkdir -p "$root/opt/rtsp-view" "$root/usr/bin" "$root/usr/share/applications" "$root/DEBIAN" "$PWD/dist"
cp -a "$PWD/build/rtsp-view-linux-x64/." "$root/opt/rtsp-view/"

cat > "$root/usr/bin/rtsp-view" <<'LAUNCHER'
#!/usr/bin/env sh
exec /opt/rtsp-view/RTSPView "$@"
LAUNCHER
chmod 0755 "$root/usr/bin/rtsp-view"

cat > "$root/usr/share/applications/rtsp-view.desktop" <<'DESKTOP'
[Desktop Entry]
Name=RTSP View
Comment=Visualizador de câmeras RTSP
Exec=/usr/bin/rtsp-view
Terminal=false
Type=Application
Categories=Video;AudioVideo;
DESKTOP

cat > "$root/DEBIAN/control" <<CONTROL
Package: rtsp-view
Version: $version
Section: video
Priority: optional
Architecture: amd64
Depends: libc6, libstdc++6
Maintainer: RTSP View
Description: Visualizador multiplataforma de câmeras RTSP
 Monitoramento de múltiplas câmeras com reprodução RTSP nativa.
CONTROL

dpkg-deb --root-owner-group --build "$root" "$package"
printf 'Pacote pronto: %s\n' "$package"
