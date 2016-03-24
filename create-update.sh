#!/bin/bash
set -e

CLRVER=$(cat "$PWD/.clear-version")
MIXVER=$(cat "$PWD/.mix-version")


while [[ $# > 0 ]]
do
  key="$1"
  case $key in
    -c|--config)
    BUILDERCONF="$2"
    shift
    ;;
    -f|--format)
    FORMAT="$2"
    shift
    ;;
    -h|--help)
    echo -e "Usage: mixer-create-update.sh\n"
    echo -e "\t-c, --config Supply specific builder.conf\n"
    echo -e "\t-f, --format Supply format to use\n"
    exit
    ;;
    *)
    echo -e "Invalid option\n"
    exit
    ;;
esac
shift
done

if [ ! -z "$BUILDERCONF" ]; then
  STATE_DIR=$(grep STATE_DIR "$BUILDERCONF" | cut -d "=" -f2 | sed 's/ *//')
  BUNDLE_DIR=$(grep BUNDLE_DIR "$BUILDERCONF" | cut -d "=" -f2 | sed 's/ *//')
else
  STATE_DIR=$(grep STATE_DIR "/usr/share/defaults/bundle-chroot-builder/builder.conf" | cut -d "=" -f2 | sed 's/ *//')
  BUNDLE_DIR=$(grep BUNDLE_DIR "/usr/share/defaults/bundle-chroot-builder/builder.conf" | cut -d "=" -f2 | sed 's/ *//')
fi

if [ -z "$FORMAT" ]; then
        FORMAT="staging"
fi

export BUNDLEREPO="$BUNDLE_DIR"

if [ ! -d "$STATE_DIR/www/version/format$FORMAT" ]; then
	sudo -E mkdir -p "$STATE_DIR/www/version/format$FORMAT/"
fi

# step 1: create update content for current mix
sudo -E "swupd_create_update" -S "$STATE_DIR" --osversion $MIXVER

# step 2: create fullfiles
sudo -E "swupd_make_fullfiles" -S "$STATE_DIR" $MIXVER

# step 3: create zero/delta packs
for bundle in $(ls "$BUNDLEREPO"); do
	sudo -E "swupd_make_pack" -S "$STATE_DIR" 0 $MIXVER $bundle
done

# step 4: hardlink relevant dirs
sudo -E "hardlink" -f "$STATE_DIR/image/$MIXVER"/*

# step 5: update latest version
sudo cp "$PWD/.mix-version" "$STATE_DIR/image/latest.version"
sudo cp "$PWD/.mix-version" "$STATE_DIR/www/version/format$FORMAT/latest"
# vi: ts=8 sw=2 sts=2 et tw=80
