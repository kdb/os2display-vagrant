#!/usr/bin/env bash
dir=$(cd $(dirname "${BASH_SOURCE[0]}")/../ && pwd)

mkdir -p $dir/htdocs
cd $dir/htdocs

git clone git@github.com:search-node/search_node.git search_node

git clone git@github.com:os2display/docs.git docs
git clone -b feature/upgrade-v5 git@github.com:kdb/os2display-admin.git admin
git clone git@github.com:os2display/middleware.git middleware
git clone git@github.com:os2display/screen.git screen

cat <<EOF
Run

  $dir/scripts/install_bundles.sh

to clone bundles needed for development.

EOF
