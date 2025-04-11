#!/usr/bin/env sh

BUILDROOT=/tmp/equinox-appimage

mkdir $BUILDROOT
mkdir $BUILDROOT/usr
mkdir $BUILDROOT/usr/bin
mkdir $BUILDROOT/usr/lib

if [ -f "linuxdeploy-x86_64.AppImage" ]; then
	echo "* linuxdeploy already downloaded"
else
	curl -L -o linuxdeploy-x86_64.AppImage https://github.com/linuxdeploy/linuxdeploy/releases/latest/download/linuxdeploy-x86_64.AppImage
	chmod +x linuxdeploy-x86_64.AppImage
fi

cp src/gui/equinox.desktop $BUILDROOT/
cp -r assets $BUILDROOT/

# Compile and move the binaries in the build root
nimble build
mv ./equinox $BUILDROOT/usr/bin/
mv ./equinox_gui $BUILDROOT/usr/bin/

cat > "$BUILDROOT/AppRun" << 'EOF'
#!/bin/bash
HERE="$(dirname "$(readlink -f "$0")")"
export LD_LIBRARY_PATH="$HERE/usr/lib:$HERE/usr/lib64:$LD_LIBRARY_PATH"
export GSETTINGS_SCHEMA_DIR="$HERE/usr/share/glib-2.0/schemas"
exec "$HERE/usr/bin/equinox_gui" auto --appimage-build-root:$HERE "$@"
EOF

chmod +x $BUILDROOT/AppRun

export NO_STRIP=1
./linuxdeploy-x86_64.AppImage \
  --appdir $BUILDROOT \
  --icon-file $BUILDROOT/assets/equinox.svg \
  --desktop-file $BUILDROOT/equinox.desktop \
  --executable $BUILDROOT/usr/bin/equinox \
  --executable $BUILDROOT/usr/bin/equinox_gui \
  --output appimage
