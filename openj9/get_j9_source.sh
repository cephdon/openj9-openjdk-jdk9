#!/bin/sh

usage() {
	echo "Usage: $0 [-h|--help] [-j9vm-repo=<j9vm repo url>] [-j9vm-branch=<branch>] [-j9jcl-repo=<j9jcl repo url>] [-j9jcl-branch=<branch>] [... other OpenJ9 repositories and branches options] [-parallel=<true|false>]"
	echo "where:"
	echo "  -h|--help         print this help, then exit"
	echo "  -j9vm-repo        the OpenJ9/vm repository url: git002@gitlab-polyglot.hursley.ibm.com:j9/j9vm.git"
	echo "                    or <user>@gitlab-polyglot.hursley.ibm.com:<namespace>/j9vm.git"
	echo "  -j9vm-branch      the OpenJ9/vm git branch: master "
	echo "  -omr-repo         the OpenJ9/omr repository url: git002@gitlab-polyglot.hursley.ibm.com:omr/omr.git"
	echo "                    or <user>@gitlab-polyglot.hursley.ibm.com:<namespace>/omr.git"
	echo "  -omr-branch       the OpenJ9/omr git branch: java-master "
	echo "  -binaries-repo    the OpenJ9/binaries repository url: git002@gitlab-polyglot.hursley.ibm.com:j9/binaries.git"
	echo "                    or <user>@gitlab-polyglot.hursley.ibm.com:<namespace>/binaries.git"
	echo "  -binaries-branch  the OpenJ9/binaries git branch: master "
	echo "  -jit-repo         the OpenJ9/jit repository url: git002@gitlab-polyglot.hursley.ibm.com:jit/tr.open.git"
	echo "                    or <user>@gitlab-polyglot.hursley.ibm.com:<namespace>/tr.open.git "
	echo "  -jit-branch       the OpenJ9/jit git branch: java-master "
	echo "  -parallel         (boolean) if 'true' then the clone j9 repository commands run in parallel, default is false"
	echo ""
	exit 1
}

# require bash 4.0 or later to support associative arrays
bash_version=`bash --version | sed -n 1p`
if [[ $bash_version != *"version 4."* ]] ; then
	echo "Bash version 4.0 or later is required!"
	exit 1
fi

declare -A j9repos
declare -A branches
declare -A default_j9repos=( [j9vm]=j9/j9vm [omr]=omr/omr [binaries]=j9/binaries [tr.open]=jit/tr.open )
declare -A default_branches=( [j9vm]=master [omr]=java-master [binaries]=master [tr.open]=java-master )
declare -A commands

pflag="false"
base_git_url=git002@gitlab-polyglot.hursley.ibm.com

for i in "$@"
do
	case $i in
		-h | --help )
		usage
		;;

		-r=* | --revision=* )
		hgtag="${i#*=}"
		;;

		-j9vm-repo=* )
		j9repos[j9vm]="${i#*=}"
		;;

		-j9vm-branch=* )
		branches[j9vm]="${i#*=}"
		;;

		-omr-repo=* )
		j9repos[omr]="${i#*=}"
		;;

		-omr-branch=* )
		branches[omr]="${i#*=}"
		;;

		-binaries-repo=* )
		j9repos[binaries]="${i#*=}"
		;;

		-binaries-branch=* )
		branches[binaries]="${i#*=}"
		;;

		-jit-repo=* )
		j9repos[tr.open]="${i#*=}"
		;;

		-jit-branch=* )
		branches[tr.open]="${i#*=}"
		;;

		-parallel=* )
		pflag="${i#*=}"
		;;

		'--' ) # no more options
		usage
		;;

		-*) # bad option
		usage
		;;

		*) # bad option
		usage
		;;
	esac
done

git=`which git`

# clone OpenJ9 repos
date '+[%F %T] Get OpenJ9 sources'
START_TIME=$(date +%s)

for i in "${!default_j9repos[@]}" ; do
	branch=${default_branches[$i]}
	if [ ${branches[$i]+_} ]; then
		branch=${branches[$i]}
	fi

	if [ -d ${i} ]; then
		echo
		echo "Update ${i} source"
		echo

                cd ${i}
		git fetch origin || exit$?
		git pull --rebase origin ${branch} || exit $?
		cd -
        else
		git_url=${base_git_url}:${default_j9repos[$i]}.git

		if [ ${j9repos[$i]+_} ]; then
			git_url="${j9repos[$i]}"
		fi

		git_clone_command="${git} clone --recursive -b ${branch} ${git_url} ${i}"
		commands[$i]=${git_clone_command}

		echo
		echo "Clone repository: ${i}"
		echo

		if [ ${pflag} = "true" ] ; then
			# run git clone in parallel
			( ${git_clone_command} ; echo "$?" > /tmp/${i}.pid.rc ) 2>&1 &
		else
			${git_clone_command} || exit $?
		fi
	fi
done

if [ ${pflag} = "true" ] ; then
	# Wait for all subprocesses to complete
	wait
fi

END_TIME=$(date +%s)
date "+[%F %T] OpenJ9 clone repositories finished in $(($END_TIME - $START_TIME)) seconds"

for i in "${!default_j9repos[@]}" ; do
	if [ -e /tmp/${i}.pid.rc ]; then
		rc=`cat /tmp/${i}.pid.rc | tr -d ' \n\r'`

		if [ "$rc" -ne "0" ]; then
			echo "ERROR: repository ${i} exited abnormally!"
			cat /tmp/${i}.pid.rc
			echo "Re-run: ${commands[$i]}"

			# clean up sources
			if [ -d ${i} ] ; then
				rm -fdr ${i}
			fi

			# clean up pid file
			rm -f /tmp/${i}.pid.rc
			exit 1
		fi
	fi
done
