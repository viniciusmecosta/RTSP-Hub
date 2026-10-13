#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != "Linux" || "$(uname -m)" != "x86_64" ]]; then
  printf '%s\n' 'Este empacotador requer Linux x86_64.' >&2
  exit 1
fi

if ! pkg-config --exists gtk+-3.0 mpv epoxy libsecret-1; then
  printf '%s\n' 'Instale os pacotes de desenvolvimento GTK, mpv, epoxy e libsecret para compilar o aplicativo Linux.' >&2
  exit 1
fi

flutter build linux --release
bundle="$PWD/build/linux/x64/release/bundle"
mpv_plugin="$bundle/lib/libmedia_kit_video_plugin.so"
if [[ ! -f "$mpv_plugin" ]]; then
  printf '%s\n' 'O plugin de vídeo não foi incluído no build Linux.' >&2
  exit 1
fi
mpv_path="$(ldd "$mpv_plugin" | awk '$1 ~ /^libmpv\.so\.[0-9]+$/ && $2 == "=>" && $3 ~ /^\// { print $3; exit }')"
if [[ -z "$mpv_path" || ! -f "$mpv_path" ]]; then
  printf '%s\n' 'A biblioteca libmpv exigida pelo build Linux não foi encontrada.' >&2
  exit 1
fi

stage="$PWD/build/rtsp-view-linux-x64"
output="$PWD/dist/rtsp-view-linux-x64.tar.gz"
rm -rf "$stage"
mkdir -p "$stage/lib" "$(dirname "$output")"
cp -a "$bundle/." "$stage/"

queue=("$mpv_path")
while IFS= read -r library; do
  queue+=("$library")
done < <(find "$bundle/lib" -type f -name '*.so*' -print)
seen=' '
while ((${#queue[@]})); do
  source="${queue[0]}"
  queue=("${queue[@]:1}")
  [[ -f "$source" ]] || continue
  name="$(basename "$source")"
  [[ "$seen" == *" $name "* ]] && continue
  seen+="$name "
  cp -L "$source" "$stage/lib/$name"
  while IFS= read -r dependency; do
    [[ -f "$dependency" ]] || continue
    dependency_name="$(basename "$dependency")"
    case "$dependency_name" in
      libc.so.*|libm.so.*|libpthread.so.*|libdl.so.*|librt.so.*|libresolv.so.*|libutil.so.*|libanl.so.*|ld-linux*.so.*|linux-vdso.so.*) continue ;;
    esac
    queue+=("$dependency")
  done < <(ldd "$source" 2>/dev/null | awk '/=> \// { print $3 } /^\// { print $1 }')
done

cat > "$stage/RTSPView" <<'LAUNCHER'
#!/usr/bin/env sh
APP_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
export LD_LIBRARY_PATH="$APP_DIR/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
exec "$APP_DIR/rtsp_view" "$@"
LAUNCHER
chmod +x "$stage/RTSPView"
tar -C "$PWD/build" -czf "$output" "$(basename "$stage")"
printf 'Pacote pronto: %s\n' "$output"
