#!/usr/bin/env bash
set -euo pipefail

WOW_ROOT="${WOW_ROOT:-/Applications/World of Warcraft}"
DEFAULT_CLIENT="_classic_beta_"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INCLUDE_SKIPPED=0

usage() {
	echo "Usage: $0 [--all] [client-folder-or-addons-path]"
	echo "Copies each addon into the client as a real folder. Re-run after editing."
	echo "SavedVariables persist across /reload and relog."
	echo "Default: $WOW_ROOT/$DEFAULT_CLIENT/Interface/AddOns"
	echo "By default BagMaster and SplitChat are not copied (and are removed from"
	echo "AddOns if a previous copy is there). Pass --all to include them."
	echo "Examples:"
	echo "  $0"
	echo "  $0 --all"
	echo "  $0 $DEFAULT_CLIENT"
	echo "  $0 \"$WOW_ROOT/$DEFAULT_CLIENT/Interface/AddOns\""
}

skip_addon() {
	local name="$1"
	[[ "$INCLUDE_SKIPPED" -eq 1 ]] && return 1
	case "$name" in
		BagMaster|SplitChat) return 0 ;;
		*) return 1 ;;
	esac
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
		--all)
			INCLUDE_SKIPPED=1
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
skipped=0
for addon_dir in "$REPO_ROOT"/*/; do
	src="${addon_dir%/}"
	name="$(basename "$src")"
	if [[ ! -f "$src/${name}.toc" ]]; then
		continue
	fi
	dest="$addons_dir/$name"

	if skip_addon "$name"; then
		if [[ -e "$dest" || -L "$dest" ]]; then
			rm -rf "$dest"
			echo "Skipped $name (removed from AddOns). Pass --all to copy."
		else
			echo "Skipped $name. Pass --all to copy."
		fi
		skipped=$((skipped + 1))
		continue
	fi

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

if [[ "$copied" -eq 0 && "$skipped" -eq 0 ]]; then
	echo "No addon folders found in $REPO_ROOT (expected FolderName/FolderName.toc)"
	exit 1
fi

echo "AddOns path: $addons_dir"
echo
echo "Copied $copied addon(s). Re-run this after editing, since the client now has"
echo "its own copy. Fully restart WoW if the game is open."
