#!/usr/bin/env bash
set -euo pipefail

WOW_ROOT="${WOW_ROOT:-/Applications/World of Warcraft}"
DEFAULT_CLIENT="_classic_beta_"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

usage() {
	echo "Usage: $0 [client-folder-or-addons-path]"
	echo "Copies each addon into the client as a real folder. Re-run after editing."
	echo "SavedVariables persist across /reload and relog."
	echo "Default: $WOW_ROOT/$DEFAULT_CLIENT/Interface/AddOns"
	echo "SplitChat is parked and is removed from AddOns if a previous copy is there."
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

target=""
for arg in "$@"; do
	case "$arg" in
		-h|--help)
			usage
			exit 0
			;;
		-*)
			echo "Unknown option: $arg"
			usage
			exit 1
			;;
		*)
			if [[ -n "$target" ]]; then
				usage
				exit 1
			fi
			target="$arg"
			;;
	esac
done
target="${target:-$DEFAULT_CLIENT}"

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

	# Replace any symlink left by an older version of this script so the client
	# folder is a real copy.
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

# Renamed to BackendMaster. Drop the old client folder so both do not load.
if [[ -e "$addons_dir/Backend" || -L "$addons_dir/Backend" ]]; then
	rm -rf "$addons_dir/Backend"
	echo "Removed old Backend addon (now BackendMaster)."
fi

# Parked. Chatanator is the chat addon until SplitChat is redesigned.
if [[ -e "$addons_dir/SplitChat" || -L "$addons_dir/SplitChat" ]]; then
	rm -rf "$addons_dir/SplitChat"
	echo "Removed SplitChat (parked; use Chatanator)."
fi

if [[ "$copied" -eq 0 ]]; then
	echo "No addon folders found in $REPO_ROOT (expected FolderName/FolderName.toc)"
	exit 1
fi

echo "AddOns path: $addons_dir"
echo
echo "Copied $copied addon(s). Re-run this after editing, since the client now has"
echo "its own copy. Fully restart WoW if the game is open."
