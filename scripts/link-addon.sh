#!/usr/bin/env bash
set -euo pipefail

WOW_ROOT="${WOW_ROOT:-/Applications/World of Warcraft}"
DEFAULT_CLIENT="_classic_beta_"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

usage() {
	echo "Usage: $0 [client-folder-or-addons-path]"
	echo "Copies each addon into the client as a real folder. Symlinked addons load"
	echo "their Lua but the client never reads back their SavedVariables."
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
copied=0
for addon_dir in "$REPO_ROOT"/*/; do
	src="${addon_dir%/}"
	name="$(basename "$src")"
	if [[ ! -f "$src/${name}.toc" ]]; then
		continue
	fi
	dest="$addons_dir/$name"

	# Replace any symlink left by an older version of this script. A symlinked addon
	# folder loads its Lua normally but the client does not read its SavedVariables
	# back, so saved data silently resets on every login.
	if [[ -L "$dest" ]]; then
		rm -f "$dest"
	fi

	if command -v rsync >/dev/null 2>&1; then
		mkdir -p "$dest"
		# --delete so a file removed from the repo also disappears from the client.
		rsync -a --delete \
			--exclude '.git/' \
			--exclude '.gitignore' \
			--exclude '.DS_Store' \
			"$src"/ "$dest"/
	else
		rm -rf "$dest"
		cp -R "$src" "$dest"
		rm -rf "$dest/.git" "$dest/.gitignore"
		find "$dest" -name '.DS_Store' -delete 2>/dev/null || true
	fi

	echo "Copied $name -> $dest"
	copied=$((copied + 1))
done

if [[ "$copied" -eq 0 ]]; then
	echo "No addon folders found in $REPO_ROOT (expected FolderName/FolderName.toc)"
	exit 1
fi

echo "AddOns path: $addons_dir"
echo
echo "Copied $copied addon(s). Re-run this after editing, since the client now has"
echo "its own copy. Fully restart WoW if the game is open."
