#!/usr/bin/env bash
# Puts the EEA file at data/raw/CLRTAP_NFR19_V26_1_GF.csv, downloading it if
# it is not there, and checks it is byte for byte the file the findings in
# docs/FINDINGS.md were produced from.
#
# Needs: curl, unzip, and sha256sum or shasum.
#
#   scripts/fetch_data.sh
#
# The download is the EEA's "Download all files" archive for this edition of
# the dataset (about 1.3 GB, also holding an Access copy of the same data).
# Only the CSV is kept. If the share link stops working, the same archive is
# reachable from the dataset's DOI page (docs/SOURCES.md): download it by hand
# into data/raw/ and run this script again.
set -euo pipefail
cd "$(dirname "$0")/.."

URL=https://sdi.eea.europa.eu/datashare/s/ot4TQCkALbXQEnB/download
ARCHIVE=data/raw/eea_t_lrtap-convention_p_1980-2024_v01_r00.zip
CSV=data/raw/CLRTAP_NFR19_V26_1_GF.csv
SHA256=b4f04584358f36b6b643976593bfe0b400e174c00827bb45066a4e3da008c505

sha256_of() {
    if command -v sha256sum >/dev/null; then
        sha256sum "$1" | cut -d' ' -f1
    else
        shasum -a 256 "$1" | cut -d' ' -f1
    fi
}

mkdir -p data/raw

if [ ! -f "$CSV" ]; then
    if [ ! -f "$ARCHIVE" ]; then
        echo "Downloading the EEA archive (about 1.3 GB)"
        curl -fL --retry 3 -o "$ARCHIVE.part" "$URL"
        mv "$ARCHIVE.part" "$ARCHIVE"
    fi
    echo "Extracting $(basename "$CSV")"
    # -j drops whatever folder the archive keeps the file in.
    unzip -j -o "$ARCHIVE" "*$(basename "$CSV")" -d data/raw
    rm "$ARCHIVE"
fi

actual=$(sha256_of "$CSV")
if [ "$actual" != "$SHA256" ]; then
    cat >&2 <<EOF
$CSV is not the file this project's findings were produced from.
  expected sha256 $SHA256
  actual   sha256 $actual
The EEA may have revised the dataset. Stopping, so that results from it are
not mistaken for those in docs/FINDINGS.md, which describe the original file.
EOF
    exit 1
fi
echo "$CSV verified"
