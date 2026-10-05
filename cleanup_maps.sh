#!/usr/bin/env bash
set -euo pipefail

# Determine maps directory
if [ -d "./cstrike/maps" ]; then
    MAPS_DIR="./cstrike/maps"
elif [ -d "./maps" ]; then
    MAPS_DIR="./maps"
else
    echo "Error: Maps directory not found in ./cstrike/maps or ./maps" >&2
    exit 1
fi

echo "Cleaning maps in: $MAPS_DIR"

# Whitelist prefixes
KEEP_PATTERNS=(
    "de_dust2"
    "de_inferno"
    "de_nuke"
    "de_train"
    "de_mirage"
    "de_cache"
    "de_cbble"
    "de_aztec"
    "de_prodigy"
    "cs_assault"
    "cs_italy"
    "cs_office"
    "cs_militia"
    "aim_botz"
    "aim_reflex_v2"
    "fy_pool_day"
    "awp_india"
    "bhop_arena"
    "bhop_easy"
)

deleted_count=0
kept_count=0

shopt -s nullglob
for file in "$MAPS_DIR"/*; do
    if [ ! -f "$file" ]; then
        continue
    fi

    filename="$(basename "$file")"
    keep=false

    for prefix in "${KEEP_PATTERNS[@]}"; do
        if [[ "$filename" == "$prefix"* ]]; then
            keep=true
            break
        fi
    done

    if [ "$keep" = true ]; then
        ((kept_count++))
    else
        rm -f "$file"
        ((deleted_count++))
    fi
done

echo "Done. Kept $kept_count files, deleted $deleted_count files."
