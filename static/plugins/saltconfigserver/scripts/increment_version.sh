#!/bin/bash

BRANCH="$1"
POS="$2"

REPOHOME="/srv/freesat/git-repo"
REPONAME="fdp-mgmt-salt"
REPOTMP="/var/cache/obdi/gitrepo"

delete_repo_cache() {

    # REPOTMP does not exist so no need to delete
	[[ ! -e "$REPOTMP/$REPONAME" ]] && return

    # REPOTMP is not a directory
	[[ ! -d "$REPOTMP/$REPONAME" ]] && {
		echo -n '{"Error":"The location, `'"$REPOTMP/$REPONAME"'`, is not a'
		echo ' directory. Aborting."}'
		exit 1
	}

	[[ ! -e "$REPOTMP/$REPONAME/.git" ]] && {
		echo -n '{"Error":"Directory, `'"$REPOTMP/$REPONAME"'`, does not'
		echo -n ' contain a git repository, so was probably used for something'
		echo ' else. Will not delete the directory. Aborting."}'
		exit 1
	}

	rm -rf "$REPOTMP/$REPONAME/"
}

clone_repo_cache() {

	# Create the repo cache directory
	mkdir -p "$REPOTMP"

	# Update the repo
	cd "$REPOHOME/$REPONAME.git"
	git fetch

	# Clone the repo
	cd "$REPOTMP"
	git clone "$REPOHOME/$REPONAME.git" >/dev/null
}

get_latest_version_string() {
	cd $REPOTMP/$REPONAME

	git branch -a | \
		sed -n 's#^\s*remotes/origin/'"$BRANCH"'_\(\)#\1#p' | \
		sort -nt . -k1,1 -k2,2 -k3,3 -k4,4 | \
		tail -n 1
}

increment_version_string() {
	# Arg1 - version, e.g.      0.1.10

	local version="$1"
	local -i pos=$POS
	local a
	
	IFS="." read -a a < <( echo "$version" )
	for i in 1 2 3; do
		if [[ $i == $pos ]]; then
			echo "$version" | awk -F. '{ printf( "%s", $'"$pos"'+1 ); }'
			a[$i]=0
			a[$i+1]=0
		else
			echo -n "${a[$i-1]}"
		fi
		[[ $i -lt 3 ]] && echo -n "."
	done
}

create_branch() {
	# Arg1 - version

	cd $REPOTMP/$REPONAME

	git checkout $BRANCH
	git branch ${BRANCH}_$1
	git push origin ${BRANCH}_$1

	/etc/init.d/salt-master restart
}

main() {
	local version new_version

	[[ -z $BRANCH ]] && {
		echo '{"Error":"Argument 1 missing. Expected a branch name."}'
		exit 1
	}

	[[ -z $POS ]] && {
		echo '{"Error":"Argument 2 missing. Expected a position to increment."}'
		exit 1
	}

	delete_repo_cache

	clone_repo_cache

	version=`get_latest_version_string`

	new_version=`increment_version_string "$version"`

	create_branch "$new_version"
}

main

# vim:ts=4:sw=4:noet
