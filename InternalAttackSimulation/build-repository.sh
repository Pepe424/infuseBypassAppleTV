#!/bin/sh

set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
expected_bundle=com.firecore.infuse.securitytest
package_id=com.pepe424.infusesecuritytestattack
package_version=$(sed -n 's/^Version:[[:space:]]*//p' "$project_dir/control")
repository_dir="$project_dir/repository"
temporary_dir=$(mktemp -d)

cleanup() {
    rm -rf -- "$temporary_dir"
}
trap cleanup EXIT HUP INT TERM

plist_bundle=$(plutil -extract Filter.Bundles.0 raw -o - \
    "$project_dir/InfuseAttackSimulation.plist")
if [ "$plist_bundle" != "$expected_bundle" ]; then
    echo "Refusing to publish filter for non-test bundle: $plist_bundle" >&2
    exit 1
fi

expected_declaration="static NSString *const IASTargetBundleIdentifier = @\"$expected_bundle\";"
if ! grep -Fqx "$expected_declaration" "$project_dir/InfuseAttackSimulation.mm"; then
    echo "Refusing to publish: runtime bundle guard is not $expected_bundle" >&2
    exit 1
fi

: "${THEOS:=$HOME/theos}"
export THEOS

cd "$project_dir"
make clean package FINALPACKAGE=1

package_path="$project_dir/packages/${package_id}_${package_version}_appletvos-arm64.deb"
if [ ! -f "$package_path" ]; then
    echo "Expected package was not produced: $package_path" >&2
    exit 1
fi

mkdir -p "$repository_dir/debs" "$temporary_dir/debs"
cp "$package_path" "$repository_dir/debs/"
cp "$package_path" "$temporary_dir/debs/"

cd "$temporary_dir"
dpkg-scanpackages debs /dev/null > Packages
gzip -9 -n -c Packages > Packages.gz
bzip2 -9 -c Packages > Packages.bz2
cp Packages Packages.gz Packages.bz2 "$repository_dir/"

md5_file() {
    if command -v md5 >/dev/null 2>&1; then
        md5 -q "$1"
    else
        md5sum "$1" | awk '{print $1}'
    fi
}

release_date=$(date -u '+%a, %d %b %Y %H:%M:%S UTC')
{
    echo 'Origin: Infuse Internal Security Test'
    echo 'Label: InfuseAttackSimulation'
    echo 'Suite: internal'
    echo 'Codename: internal'
    echo 'Version: 1.0'
    echo 'Architectures: appletvos-arm64'
    echo 'Components: main'
    echo 'Description: Internal attack-simulation packages for the isolated Infuse test build'
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

echo "Private repository updated for $(basename -- "$package_path")"
