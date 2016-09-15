#!/bin/sh

usage() {
	echo "Usage: $0 [-h|--help] [-j9vm-repo=<user>/j9vm] [-j9vm-branch=<branch>] [-j9jcl-repo=<user>/j9jcl] [-j9jcl-branch=<branch>] [... other OpenJ9 repositories and branches options]"
	echo "where:"
	echo "	-h|--help 			print this help, then exit"
	echo "	-j9vm-repo			the OpenJ9/vm git fork: default: j9/j9vm "
	echo "	-j9vm-branch		the OpenJ9/vm git branch: default: master "
	echo "	-j9jcl-repo			the OpenJ9/j9jcl git fork: default: j9/j9jcl "
	echo "	-j9jcl-branch		the OpenJ9/j9jcl git branch: default: master "
	echo "	-omr-repo			the OpenJ9/omr git fork: default: omr/omr "
	echo "	-omr-branch			the OpenJ9/omr git branch: default: java-master "
	echo "	-binaries-repo		the OpenJ9/binaries git fork: default: j9/binaries "
	echo "	-binaries-branch	the OpenJ9/binaries git branch: default: master "
	echo "	-tooling-repo		the OpenJ9/tooling git fork: default: j9/tooling "
	echo "	-tooling-branch		the OpenJ9/tooling git branch: default: master "
	echo "	-rtctest-repo		the OpenJ9/rtctest git fork: default: j9/rtctest "
	echo "	-test-branch		the OpenJ9/test git branch: default: master "
	echo "	-test-repo			the OpenJ9/test git fork: default: j9/test "
	echo "	-rtctest-branch		the OpenJ9/rtctest git branch: default: master "
	echo "	-jit-repo			the OpenJ9/jit git fork: default: jit/tr.open "
	echo "	-jit-branch			the OpenJ9/jit git branch: default: java-master "
	echo " "
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
declare -A default_j9repos=( [j9vm]=j9/j9vm [j9jcl]=joe_dekoning-ca/j9jcl [omr]=omr/omr [binaries]=j9/binaries [tooling]=j9/tooling [rtctest]=j9/rtctest [test]=j9/test [jit]=jit/tr.open )
declare -A default_branches=( [j9vm]=master [j9jcl]=master [omr]=java-master [binaries]=master [tooling]=master [rtctest]=master [test]=master [jit]=java-master )


ostype=`uname -s`

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

		-j9jcl-repo=* )
		j9repos[j9jcl]="${i#*=}"
		;;

		-j9jcl-branch=* )
		branches[j9jcl]="${i#*=}"
		;;

		-omr-repo=* )
		j9repo[omr]="${i#*=}"
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

		-tooling-repo=* )
		j9repos[tooling]="${i#*=}"
		;;

		-tooling-branch=* )
		branches[tooling]="${i#*=}"
		;;

		-rtctest-repo=* )
		j9repos[rtctest]="${i#*=}"
		;;

		-rtctest-branch=* )
		branches[rtctest]="${i#*=}"
		;;

		-test-repo=* )
		j9repos[test]="${i#*=}"
		;;

		-test-branch=* )
		branches[test]="${i#*=}"
		;;
		
		-jit-repo=* )
		j9repos[jit]="${i#*=}"
		;;

		-jit-branch=* )
		branches[jit]="${i#*=}"
		;;

		'--' ) # no more options
		usage
		;;

		-*)  # bad option
		usage
		;;

		*)  # bad option
		usage
		;;
	esac
done

# Get clones of all the Open J9 repositories
git=`which git`

# find git url 
repo_url=`git config --local --get remote.origin.url`
protocol=https

if [[ $repo_url == *"$protocol"* ]] ; then 
	# http protocol: e.g. https://gitlab-polyglot.hursley.ibm.com/omr/openjdk.git
	b=`expr index ${repo_url:8} /`
	git_url=`expr substr ${repo_url:8} 1 $b`
	git_url="https://${git_url}"
else
	# ssh protocol: e.g. git002@gitlab-polyglot.hursley.ibm.com:omr/openjdk.git
	b=`expr index $repo_url :`
	git_url=`expr substr $repo_url 1 $b`
fi

# clone OpenJ9 repos
echo "Get OpenJ9 sources"

for i in "${!default_j9repos[@]}" ; do
	# work-around for test repo
	if [ ${i} = "test"  ]; then
		output="j9test"
	else
		output=$i
	fi 
	# clone repo
	branch=${default_branches[$i]}
	if [ ${branches[$i]+_} ]; then
		branch=${branches[$i]}
		fi

		repo="${default_j9repos[$i]}.git"
	if [ ${j9repos[$i]+_} ]; then
		repo="${j9repos[$i]}.git"
		fi

		git_clone_command="${git} clone -b ${branch} ${git_url}${repo} ${output}"
	echo "Servicing $i"
	${git_clone_command} || exit $?
done
