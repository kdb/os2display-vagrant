#!/usr/bin/env bash
script_dir=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
dir=$(cd $(dirname "${BASH_SOURCE[0]}")/../htdocs/admin && pwd)

cd $dir
COMPOSER=$dir/../../scripts/composer-dev.json composer update --verbose
