#!/usr/bin/env bash
# http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -euo pipefail
IFS=$'\n\t'

gitRepoReferenceBase='/home/bamboo2/.temp-git-repo-reference'
buildSubString="xml-data/build-dir"

logInfo() {
	echo "LOG-INFO: $@"
}

die() {
	(>&2 echo -e "ERROR: $@")
	exit 1
}

setupGitRepositoryReference() {
	# Here to stop problems with parallel runs on local agents. Every job has an AgentId and there can only be
	# one job running per agent at any single point of time.
	if [ -n "$bamboo_agentId" ]; then
		logInfo "Found Bamboo AgentId: $bamboo_agentId. Checking for git repository reference."
		gitRefLocation="$gitRepoReferenceBase/agent_$bamboo_agentId/${bamboo_planRepository_repositoryUrl//*\/}.reference"
		if [ ! -d "$gitRefLocation" ]; then
			logInfo "First time checkout of reference repository '$gitRefLocation'."
			mkdir -p $gitRefLocation
			if ! git clone "$bamboo_planRepository_repositoryUrl" $gitRefLocation; then
				rm -rf "$gitRefLocation"
			fi
		else
			logInfo "Found git reference repository '$gitRefLocation'. Updating..."
			#git -C $gitRefLocation pull --rebase # option '-C' only available in > v1.8.5
			git --git-dir="$gitRefLocation/.git" --work-tree="$gitRefLocation" fetch
		fi
	fi
}

if [ -n "$bamboo_build_working_directory" ]; then
	# sanity check - make sure we are deleting the right thing
	[[ "$bamboo_build_working_directory" == *"$buildSubString"* ]] || die "Working directory '$bamboo_build_working_directory' does not contain sub-string '$buildSubString' "
	# pre-checkout cleaning...
	#logInfo "Listing bamboo_build_working_directory BEFORE..."
	#ls -al "$bamboo_build_working_directory"
	logInfo "Cleaning bamboo_build_working_directory '$bamboo_build_working_directory'..."
	cd "$bamboo_build_working_directory" && rm -rf ..?* .[!.]* *
	logInfo "Listing bamboo_build_working_directory AFTER..."
	ls -al
	# checkout and branch handling...
	setupGitRepositoryReference;
	if [ -n "$gitRefLocation" ]; then
		logInfo "Checking out using reference repo '$gitRefLocation'."
		git clone --reference $gitRefLocation "$bamboo_planRepository_repositoryUrl" . && git repack -a -d && find $(find . -name .git) -name alternates | xargs rm
		git checkout $bamboo_planRepository_revision
	else
		logInfo "Checking out WITHOUT using reference repo."
		git clone "$bamboo_planRepository_repositoryUrl" .
	fi
	logInfo "Checking out '$bamboo_planRepository_branchName' with rev '$bamboo_planRepository_revision'"
	git checkout $bamboo_planRepository_revision
else
    die "No bamboo_build_working_directory set"
fi
