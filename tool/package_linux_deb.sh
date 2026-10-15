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

root="$PWD/build/rtsp-hub-deb"
package="$PWD/dist/rtsp-hub_${version}_amd64.deb"
"$PWD/tool/package_linux.sh"
rm -rf "$root"
mkdir -p "$root/opt/rtsp-hub" "$root/usr/bin" "$root/usr/share/applications" "$root/usr/share/icons" "$root/usr/share/pixmaps" "$root/DEBIAN" "$PWD/dist"
cp -a "$PWD/build/rtsp-hub-linux-x64/." "$root/opt/rtsp-hub/"

# Instalar ícones nos padrões do Linux/Debian
if [[ -d "$PWD/linux/icons/hicolor" ]]; then
  cp -a "$PWD/linux/icons/hicolor" "$root/usr/share/icons/"
fi
if [[ -f "$PWD/linux/icons/pixmaps/rtsp-hub.png" ]]; then
  cp -a "$PWD/linux/icons/pixmaps/rtsp-hub.png" "$root/usr/share/pixmaps/rtsp-hub.png"
fi

cat > "$root/usr/bin/rtsp-hub" <<'LAUNCHER'
#!/usr/bin/env sh
exec /opt/rtsp-hub/RTSPHub "$@"
LAUNCHER
chmod 0755 "$root/usr/bin/rtsp-hub"

cat > "$root/usr/share/applications/rtsp-hub.desktop" <<'DESKTOP'
[Desktop Entry]
Name=RTSP Hub
Comment=Visualizador de câmeras RTSP
Exec=/usr/bin/rtsp-hub
Icon=rtsp-hub
Terminal=false
Type=Application
Categories=Video;AudioVideo;
DESKTOP

cat > "$root/DEBIAN/control" <<CONTROL
Package: rtsp-hub
Version: $version
Section: video
Priority: optional
Architecture: amd64
Depends: libc6, libstdc++6
Replaces: rtsp-view
Conflicts: rtsp-view
Maintainer: RTSP Hub
Description: Visualizador multiplataforma de câmeras RTSP
 Monitoramento de múltiplas câmeras com reprodução RTSP nativa.
CONTROL

dpkg-deb --root-owner-group --build "$root" "$package"
printf 'Pacote pronto: %s\n' "$package"
