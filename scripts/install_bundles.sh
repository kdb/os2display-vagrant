#!/usr/bin/env bash
set -euo pipefail
BOLD=$(tput bold)
NORMAL=$(tput sgr0)

SCRIPT_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
# Main checkout dir.
HTDOCS_DIR=$(cd $(dirname "${BASH_SOURCE[0]}")/../htdocs/ && pwd)
# Extension bundles.
BUNDLES_DIR="${HTDOCS_DIR}/bundles"

# Fetch a bundle directly from git to set us up for development.
get_bundles() {
	organization=$1
	bundles=$2
	
	mkdir -p "$BUNDLES_DIR/$organization"
	cd "$BUNDLES_DIR/$organization"
	for bundle in ${bundles[@]}; do
		tokens=(${bundle//@/ })
		repo=${tokens[0]}
		# Fall back to master branch if we don't have a revision specified.
		branch=${tokens[1]:-master}
		echo "Cloning ${BOLD}$organization/$repo@$branch -> $BUNDLES_DIR/$organization/$repo${NORMAL}"
		if [ ! -d ${repo} ]; then
				git clone "https://github.com/$organization/$repo.git"
		fi
		pushd "$repo"
		git fetch --quiet
		git checkout "$branch" --quiet || (echo "Could not find revision revision $branch" && exit 1)
		git log --oneline --max-count=1
		popd
		echo
	done
}

# Inject custom bundles into composer
configure_composer() {
	organization=$1
	bundles=$2

    pushd "${HTDOCS_DIR}/admin"
	for bundle in ${bundles[@]}; do
		tokens=(${bundle//@/ })
		repo=${tokens[0]}
		branch=${tokens[1]:-master}

		echo "Patching ${BOLD}../bundles/$organization/$repo${NORMAL} into composer-dev.json"

		COMPOSER=composer-dev.json composer config repositories.$organization/$repo path ../bundles/$organization/$repo
	done
    popd
}

#TODO function
# Prepare our "own" composer-json
ADMIN_DIR="${HTDOCS_DIR}/admin"

if [ ! -e "${ADMIN_DIR}/composer.json" ]; then
		(>&2 echo File composer.json not found in "${ADMIN_DIR}")
		exit 1
fi

if [ -e "${ADMIN_DIR}/composer-dev.json" ]; then
		(>&2 echo File "composer-dev.json" already exists in "${ADMIN_DIR}")
		# We assume this is not an error, so clean exit.
		exit
fi
cp -v "${ADMIN_DIR}/composer.json" "${ADMIN_DIR}/composer-dev.json"

# For each bundle-file in bundle.d, source it and fetch the bundle
for f in $(find ${SCRIPT_DIR}/bundle.d/ -name "*.bundle"); do
	source $f;
	get_bundles $organization $bundles
	# Customize a -dev composer json to fetch dependencies.
	configure_composer $organization $bundles
done

cat <<EOF

Bundles has been cloned, now to install them:

 $SCRIPT_DIR/install_dev.sh

EOF
