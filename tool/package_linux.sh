#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != "Linux" || "$(uname -m)" != "x86_64" ]]; then
  printf '%s\n' 'Este empacotador requer Linux x86_64.' >&2
  exit 1
fi

if ! pkg-config --exists mpv; then
  printf '%s\n' 'Instale libmpv-dev para compilar o player Linux.' >&2
  exit 1
fi

flutter build linux --release
bundle="$PWD/build/linux/x64/release/bundle"
mpv_path="$(ldconfig -p | awk '/libmpv\.so\.2 / { print $NF; exit }')"
if [[ -z "$mpv_path" || ! -f "$mpv_path" ]]; then
  printf '%s\n' 'Instale libmpv-dev e libepoxy-dev para compilar; o runtime libmpv será incluído no pacote.' >&2
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
