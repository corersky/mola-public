#!/bin/bash
# http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -euo pipefail
IFS=$'\n\t'

logInfo() {
	echo "LOG-INFO: $*"
}

die() {
	(>&2 echo -e "$@")
	exit 1
}
if [ -n "$bamboo_build_working_directory" ]; then
	# pre-checkout cleaning...
	logInfo "Cleaning bamboo_build_working_directory '$bamboo_build_working_directory'..."
	rm -rf "$bamboo_build_working_directory/*"
	logInfo "Listing bamboo_build_working_directory..."
	ls -al "$bamboo_build_working_directory"
	# checkout ad branch handling...
	cd "$bamboo_build_working_directory"
	logInfo "Checking out '$bamboo_planRepository_branchName' with rev '$bamboo_planRepository_revision'"
	git clone $bamboo_planRepository_repositoryUrl .
	git checkout $bamboo_planRepository_revision
	cd -
fi
