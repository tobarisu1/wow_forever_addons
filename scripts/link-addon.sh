#!/usr/bin/env bash
set -euo pipefail

WOW_ROOT="${WOW_ROOT:-/Applications/World of Warcraft}"
DEFAULT_CLIENT="_classic_beta_"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

usage() {
	echo "Usage: $0 [client-folder-or-addons-path]"
	echo "Default: $WOW_ROOT/$DEFAULT_CLIENT/Interface/AddOns"
	echo "Examples:"
	echo "  $0"
	echo "  $0 $DEFAULT_CLIENT"
	echo "  $0 \"$WOW_ROOT/$DEFAULT_CLIENT/Interface/AddOns\""
}

list_clients() {
	echo "Client folders in $WOW_ROOT:"
	local found=0
	local dir
	for dir in "$WOW_ROOT"/_*/; do
		echo "  $(basename "$dir")"
		found=1
	done
	if [[ "$found" -eq 0 ]]; then
		echo "  (none found)"
	fi
}

if [[ $# -gt 1 ]]; then
	usage
	exit 1
fi

if [[ $# -eq 1 && ("$1" == "-h" || "$1" == "--help") ]]; then
	usage
	exit 0
fi

target="${1:-$DEFAULT_CLIENT}"

if [[ "$target" == */Interface/AddOns || "$target" == */Interface/AddOns/ ]]; then
	addons_dir="${target%/}"
	client_dir="$(cd "$(dirname "$addons_dir")/.." && pwd)"
elif [[ "$target" == /* ]]; then
	addons_dir="$target/Interface/AddOns"
	client_dir="$target"
else
	addons_dir="$WOW_ROOT/$target/Interface/AddOns"
	client_dir="$WOW_ROOT/$target"
fi

if [[ ! -d "$client_dir" ]]; then
	echo "Client folder not found: $client_dir"
	list_clients
	exit 1
fi

mkdir -p "$addons_dir"

shopt -s nullglob
linked=0
for addon_dir in "$REPO_ROOT"/*/; do
	src="${addon_dir%/}"
	name="$(basename "$src")"
	if [[ ! -f "$src/${name}.toc" ]]; then
		continue
	fi
	dest="$addons_dir/$name"
	ln -sfn "$src" "$dest"
	echo "Linked $name -> $dest"
	linked=$((linked + 1))
done

if [[ "$linked" -eq 0 ]]; then
	echo "No addon folders found in $REPO_ROOT (expected FolderName/FolderName.toc)"
	exit 1
fi

echo "AddOns path: $addons_dir"
