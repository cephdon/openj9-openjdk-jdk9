#!/bin/sh
#Clone IBM OpenJ9 repositories
usage() {
	echo "Usage: $0 [-h|--help] or [-r|--with-hg-tag]"
	echo "-h|--help print this help, then exit"
	echo " when -r|--with-hg-tag is provided get the OpenJDK sources for given "
	echo " tag, otherwise get the latest sources "
    echo " "
    exit 1
}

hgtag="jdk-9+95"

for i in "$@"
do
	case $1 in
   		-h | --help )
    	$usage
    	exit
    	;;
		
		-r=* | --revision=* )
		hgtag="${i#*=}"
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

j9_repos="vm j9jcl"

git=`which git`
git_config_file=`find . -name config`
repo_url=`git config -f $git_config_file --get remote.origin.url`
b=`expr index $repo_url /`
git_url=`expr substr $repo_url 1 $b`

# clone IBM OpenJ9 sources
echo "Get OpenJ9 sources"
for i in ${j9_repos} ; do
	if [ -d ${i} ] ; then
		rm -f -r ${i}
	fi

	# clone repo
	echo "Serving ${i} repository" 
	echo "executing: ${git} clone $git_url${i}.git"
	${git} clone $git_url${i}.git || exit $?
done

# clone Oracle OpenJDJ sources
echo "Get OpenJDK 9 sources"
hg=`which hg`
openjdk_src_dir="jdk9"
hgoptions=

if [ -n  "$hgtag" ]; then
    hgoptions="-u ${hgtag}"
fi

echo "executing: ${hg} clone ${hgoptions} http://hg.openjdk.java.net/jdk9/jdk9  $openjdk_src_dir"
${hg} clone ${hgoptions} http://hg.openjdk.java.net/jdk9/jdk9  $openjdk_src_dir || exit $? 

chmod -R 755 ${openjdk_src_dir}/common/bin
cd ${openjdk_src_dir}
sh ./get_source.sh

echo "Update all existing repos with sources from tag: ${hgtag}"
sh ./common/bin/hgforest.sh update -r ${hgtag}

