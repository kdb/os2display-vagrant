#!/usr/bin/env bash
bold=$(tput bold)
normal=$(tput sgr0)

bundles_dir=$(cd $(dirname "${BASH_SOURCE[0]}")/../htdocs/bundles/ && pwd)
dir=$(pwd)

composer_dev=composer-dev.json

if [ ! -e $dir/composer.json ]; then
		(>&2 echo File composer.json not found in current directory)
		exit
fi

if [ -e $dir/$composer_dev ]; then
		(>&2 echo File $composer_dev already exists)
		exit
fi

cp -v composer.json $composer_dev

name=os2display
bundles=(
	admin-bundle
	core-bundle
	default-template-bundle
	media-bundle
)

for bundle in ${bundles[@]}; do
		tokens=(${bundle//@/ })
		repo=${tokens[0]}

		echo "${bold}Unsetting $name/$repo${normal}"
		COMPOSER=$composer_dev composer config repositories.$name/$repo --unset
done



configure_composer() {
	for bundle in ${bundles[@]}; do
		tokens=(${bundle//@/ })
		repo=${tokens[0]}
		branch=${tokens[1]:-master}

		echo "${bold}Setting $name/$repo -> ../../$name/$repo${normal}"

		COMPOSER=$composer_dev composer config repositories.$name/$repo path ../../$name/$repo

		# if [ ! -d $repo ]; then
		#			git clone https://github.com/$name/$repo.git
		# fi
		# git -C $repo fetch --quiet
		# git -C $repo checkout $branch --quiet
		# git -C $repo log --oneline --max-count=1
		# echo
	done
}

name=itk-os2display
bundles=(
			aarhus-data-bundle@1.1.1
			aarhus-second-template-bundle@1.0.4
			admin-bundle@1.0.13
			campaign-bundle@develop
			core-bundle@1.0.14
			default-template-bundle@1.0.8
			exchange-bundle@1.0.1
			horizon-template-bundle@1.0.3
			lokalcenter-template-bundle@1.0.5
			media-bundle@1.0.2
			template-extension-bundle@1.1.11
			vimeo-bundle@1.0.1
			os2display-koba-integration@1.0.5
)

configure_composer

name=aakb
bundles=(
		os2display-aarhus-templates@1.0.15
)

configure_composer

rm -fr $dir/vendor

COMPOSER=$composer_dev composer install
