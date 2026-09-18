#!/bin/sh

set -eu

repository_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
package_id=com.pepe424.infusesecuritytest
package_version=$(sed -n 's/^Version:[[:space:]]*//p' "$repository_root/control")
repository_dir="$repository_root/docs"
package_dir="$repository_dir/debs"
temporary_dir=$(mktemp -d)

cleanup() {
    rm -rf -- "$temporary_dir"
}
trap cleanup EXIT HUP INT TERM

: "${THEOS:=$HOME/theos}"
export THEOS

cd "$repository_root"
make clean package FINALPACKAGE=1

package_path="$repository_root/packages/${package_id}_${package_version}_appletvos-arm64.deb"

if [ ! -f "$package_path" ]; then
    echo "Expected package was not produced: $package_path" >&2
    exit 1
fi

package_name=$(basename -- "$package_path")
mkdir -p "$package_dir" "$temporary_dir/debs"
cp "$package_path" "$package_dir/$package_name"
cp "$package_path" "$temporary_dir/debs/$package_name"

cd "$temporary_dir"
dpkg-scanpackages debs /dev/null > Packages
gzip -9 -n -c Packages > Packages.gz
bzip2 -9 -c Packages > Packages.bz2

cp Packages Packages.gz Packages.bz2 "$repository_dir/"

release_date=$(date -u '+%a, %d %b %Y %H:%M:%S UTC')

md5_file() {
    if command -v md5 >/dev/null 2>&1; then
        md5 -q "$1"
    else
        md5sum "$1" | awk '{print $1}'
    fi
}

{
    echo 'Origin: Pepe424'
    echo 'Label: InfuseSecurityTest'
    echo 'Suite: stable'
    echo 'Codename: stable'
    echo "Version: $package_version"
    echo 'Architectures: appletvos-arm64'
    echo 'Components: main'
    echo 'Description: Defensive telemetry package for Infuse on jailbroken tvOS'
    echo "Date: $release_date"
    echo 'MD5Sum:'
    for index in Packages Packages.gz Packages.bz2; do
        digest=$(md5_file "$repository_dir/$index")
        size=$(wc -c < "$repository_dir/$index" | tr -d ' ')
        echo " $digest $size $index"
    done
    echo 'SHA256:'
    for index in Packages Packages.gz Packages.bz2; do
        digest=$(shasum -a 256 "$repository_dir/$index" | awk '{print $1}')
        size=$(wc -c < "$repository_dir/$index" | tr -d ' ')
        echo " $digest $size $index"
    done
} > "$repository_dir/Release"

echo "Repository metadata updated for $package_name"
