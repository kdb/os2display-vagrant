#!/usr/bin/env bash
bold=$(tput bold)
normal=$(tput sgr0)

script_dir=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
dir=$(cd $(dirname "${BASH_SOURCE[0]}")/../htdocs/ && pwd)
bundles_dir=$(cd $(dirname "${BASH_SOURCE[0]}")/../htdocs/bundles && pwd)

branch="$1"

if [ -z "$branch" ]; then
		cat <<EOF >&2

Usage: $0 <branch>

EOF
		exit
fi

for d in $bundles_dir/*/*; do
	echo "${bold}$d${normal}"
	git -C $d fetch
	git -C $d rev-parse --quiet --verify "$branch" 2>&1 > /dev/null
	if [ $? -eq 0 ]; then
			git -C $d checkout "$branch"
			git -C $d pull
	else
		(>&2 echo "Branch $branch does not exist")
	fi
	echo
done
