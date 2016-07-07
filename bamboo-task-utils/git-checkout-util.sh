#!/bin/bash
# http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -euo pipefail
IFS=$'\n\t'

logInfo() {
	echo "LOG-INFO: $@"
}

die() {
	(>&2 echo -e "ERROR: $@")
	exit 1
}
if [ -n "$bamboo_build_working_directory" ]; then
	# sanity check - make sure we are deleting the right thing
	local buildSubString="bamboo-home/xml-data/build-dir"
	[[ "$bamboo_build_working_directory" == *"$buildSubString"* ]] || die "Working directory '$bamboo_build_working_directory' does not contain sub-string '$buildSubString' "
	# pre-checkout cleaning...
	logInfo "Listing bamboo_build_working_directory BEFORE..."
	ls -al "$bamboo_build_working_directory"
	logInfo "Cleaning bamboo_build_working_directory '$bamboo_build_working_directory'..."
	cd "$bamboo_build_working_directory" && rm -rf ..?* .[!.]* *
	logInfo "Listing bamboo_build_working_directory AFTER..."
	ls -al
	# checkout ad branch handling...
	logInfo "Checking out '$bamboo_planRepository_branchName' with rev '$bamboo_planRepository_revision'"
	git clone "$bamboo_planRepository_repositoryUrl" .
	git checkout $bamboo_planRepository_revision
else
    die "No bamboo_build_working_directory set"
fi
