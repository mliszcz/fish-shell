#!/bin/bash

set -e

ROOT_DIR="$(git rev-parse --show-toplevel)"
APP_BUILD_DIR="$ROOT_DIR/build"
APP_DIR="$APP_BUILD_DIR/AppDir"
# FISH_NCURSES_ROOT must be provided externally.

env \
  CXXFLAGS='-static-libgcc -static-libstdc++ -DTPUTS_USES_INT_ARG' \
  LDFLAGS='-static-libgcc -static-libstdc++' \
  cmake -S "$ROOT_DIR" -B "$APP_BUILD_DIR" \
  -DCMAKE_BUILD_TYPE=RelWithDebInfo \
  -DCMAKE_POLICY_DEFAULT_CMP0074=NEW \
  -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY \
  -DCMAKE_INSTALL_PREFIX=/usr \
  -DBUILD_DOCS=ON \
  -DWITH_GETTEXT=OFF \
  -DFISH_USE_SYSTEM_PCRE2=OFF \
  -DFISH_ALLOW_UNSUPPORTED_STATIC_LINKING=ON \
  -DCurses_ROOT="$FISH_NCURSES_ROOT" \
  -DCURSES_NEED_NCURSES=ON

make -C "$APP_BUILD_DIR" -j$(nproc)
make -C "$APP_BUILD_DIR" install DESTDIR="$APP_DIR"

rm -f "$APP_DIR/usr/bin/fish_indent"
rm -f "$APP_DIR/usr/bin/fish_key_reader"
rm -rf "$APP_DIR/usr/share/doc/fish"

mkdir -p "$APP_DIR/usr/share/metainfo/"
cp "$ROOT_DIR/fish.appdata.xml" "$APP_DIR/usr/share/metainfo/"

cp -r "$FISH_NCURSES_ROOT/share/terminfo" "$APP_DIR/usr/share/"

cat << 'EOF' > "$APP_DIR/AppRun"
#!/bin/bash
unset ARGV0
export TERMINFO_DIRS="$APPDIR/usr/share/terminfo:$TERMINFO_DIRS"
exec "$(dirname "$(readlink  -f "${0}")")/usr/bin/fish" ${@+"$@"}
EOF
chmod 755 "$APP_DIR/AppRun"

# Only downloads linuxdeploy if the remote file is different from local
if [ -e "$APP_BUILD_DIR"/linuxdeploy-x86_64.AppImage ]; then
  curl -Lo "$APP_BUILD_DIR"/linuxdeploy-x86_64.AppImage \
    -z "$APP_BUILD_DIR"/linuxdeploy-x86_64.AppImage \
    https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage  
else
  curl -Lo "$APP_BUILD_DIR"/linuxdeploy-x86_64.AppImage \
    https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage
fi

source "$APP_BUILD_DIR/FISH-BUILD-VERSION-FILE"
export VERSION="$FISH_BUILD_VERSION"

chmod +x "$APP_BUILD_DIR"/linuxdeploy-x86_64.AppImage
"$APP_BUILD_DIR"/linuxdeploy-x86_64.AppImage \
  --appdir "$APP_DIR" \
  -d "$ROOT_DIR/fish.desktop" \
  -i "$ROOT_DIR/fish.png" \
  --output appimage
