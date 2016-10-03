#!/bin/sh

#
# Copyright (c) 2010, 2014, Oracle and/or its affiliates. All rights reserved.
# DO NOT ALTER OR REMOVE COPYRIGHT NOTICES OR THIS FILE HEADER.
#
# This code is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License version 2 only, as
# published by the Free Software Foundation.  Oracle designates this
# particular file as subject to the "Classpath" exception as provided
# by Oracle in the LICENSE file that accompanied this code.
#
# This code is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
# version 2 for more details (a copy is included in the LICENSE file that
# accompanied this code).
#
# You should have received a copy of the GNU General Public License version
# 2 along with this work; if not, write to the Free Software Foundation,
# Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA.
#
# Please contact Oracle, 500 Oracle Parkway, Redwood Shores, CA 94065 USA
# or visit www.oracle.com if you need additional information or have any
# questions.
#

to_stderr() {
    echo "$@" >&2
}

error() {
    to_stderr "ERROR: $1"
    exit ${2:-126}
}

warning() {
    to_stderr "WARNING: $1"
}

version_field() {
  # rev is typically omitted for minor and major releases
  field=`echo ${1}.0 | cut -f ${2} -d .`
  if expr 1 + $field >/dev/null 2> /dev/null; then
    echo $field
  else
    echo -1
  fi
}

usage() {
	echo "Usage: $0 [-h|--help] [-r|--revision=<tag>] [-j9|--with-j9] [... other j9 options]"
	echo "where:"
	echo "	-h|--help 				print this help, then exit"
	echo "	-r|--revision=<tag> 	is one of: jdk-9+95, jdk-9+110, jdk-9+111, jdk-9+113 "
	echo "							[Note: fetch the given revision, otherwise get the latest sources"
	echo "	-j9|--with-j9 			get the OpenJ9 latest sources "
	echo " other j9 options (used only with -j9|--with-j9 option): "
	echo "	-j9vm-repo				the OpenJ9/vm repository url: git002@gitlab-polyglot.hursley.ibm.com:j9/j9vm.git"
	echo "							or <user>@gitlab-polyglot.hursley.ibm.com:<namespace>/j9vm.git"
	echo "	-j9vm-branch			the OpenJ9/vm git branch: master "
	echo "	-j9jcl-repo				the OpenJ9/j9jcl repository url: git002@gitlab-polyglot.hursley.ibm.com:joe_dekoning-ca/j9jcl.git"
	echo "							or <user>@gitlab-polyglot.hursley.ibm.com:<namespace>/j9jcl.git"
	echo "	-j9jcl-branch			the OpenJ9/j9jcl git branch: master "
	echo "	-omr-repo				the OpenJ9/omr repository url: git002@gitlab-polyglot.hursley.ibm.com:omr/omr.git"
	echo "							or <user>@gitlab-polyglot.hursley.ibm.com:<namespace>/omr.git"
	echo "	-omr-branch				the OpenJ9/omr git branch: java-master "
	echo "	-binaries-repo			the OpenJ9/binaries repository url: git002@gitlab-polyglot.hursley.ibm.com:j9/binaries.git"
	echo "							or <user>@gitlab-polyglot.hursley.ibm.com:<namespace>/binaries.git"
	echo "	-binaries-branch		the OpenJ9/binaries git branch: master "
	echo "	-tooling-repo			the OpenJ9/tooling repository url: git002@gitlab-polyglot.hursley.ibm.com:j9/tooling.git"
	echo "							or <user>@gitlab-polyglot.hursley.ibm.com:<namespace>/tooling.git"
	echo "	-tooling-branch			the OpenJ9/tooling git branch: master "
	echo "	-rtctest-repo			the OpenJ9/rtctest repository url: git002@gitlab-polyglot.hursley.ibm.com:j9/rtctest.git"
	echo "							or <user>@gitlab-polyglot.hursley.ibm.com:<namespace>/rtctest.git"
	echo "	-rtctest-branch			the OpenJ9/test git branch: master "
	echo "	-test-repo				the OpenJ9/test repository url: git002@gitlab-polyglot.hursley.ibm.com:j9/test.git"
	echo "							or <user>@gitlab-polyglot.hursley.ibm.com:<namespace>/test.git"
	echo "	-test-branch			the OpenJ9/test git branch: master "
	echo "	-jit-repo				the OpenJ9/jit repository url: git002@gitlab-polyglot.hursley.ibm.com:jit/tr.open.git"
	echo "							or <user>@gitlab-polyglot.hursley.ibm.com:<namespace>/tr.open.git"
	echo "	-jit-branch				the OpenJ9/jit git branch: java-master"
	echo " "
	exit 1
}

j9flag="false"
hgtag="jdk-9+113"


for i in "$@"
do
	case $i in
		-h | --help )
		usage
		;;

		-j9 | --with-j9 )
		j9flag="true"
		;;

		-j9vm-repo=* | -j9vm-branch=* | -j9jcl-repo=* | -j9jcl-branch=* | -omr-repo=* | -omr-branch=* | -binaries-repo=* | -binaries-branch=* | -tooling-repo=* | -tooling-branch=* | -rtctest-repo=* | -rtctest-branch=* |-jit-repo=* |-jit-branch=* | -test-repo=* | -test-branch=* )
		j9_repos_options="${j9_repos_options} ${i}"
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

# expected OpenJDK tags
hgtags="jdk-9+95 jdk-9+110 jdk-9+111 jdk-9+113"

# check if sources loaded
has_sources="false"
if [ ${j9flag} = "true" ] ; then
	all_repos="corba jaxp jaxws langtools jdk nashorn binaries j9vm j9jcl omr tooling rtctest j9test"
else
	all_repos="corba jaxp jaxws langtools jdk hotspot nashorn"
fi

for i in ${all_repos} ; do
	if [ -d ${i} ] ; then
		echo "${i} sources already loaded"
		has_sources="true"
	else
		has_source="false"
		break
	fi
done

if [ ${has_sources} = "true" ] ; then
	exit
fi

# Version check

# required
reqdmajor=1
reqdminor=4
reqdrev=0

# requested
rqstmajor=2
rqstminor=6
rqstrev=3


# installed
hgwhere="`command -v hg`"
if [ "x$hgwhere" = "x" ]; then
  error "Could not locate Mercurial command"
fi

hgversion="`LANGUAGE=en hg --version 2> /dev/null | sed -n -e 's@^Mercurial Distributed SCM (version \([^+]*\).*)\$@\1@p'`"
if [ "x${hgversion}" = "x" ] ; then
  error "Could not determine Mercurial version of $hgwhere"
fi

hgmajor="`version_field $hgversion 1`"
hgminor="`version_field $hgversion 2`"
hgrev="`version_field $hgversion 3`"

if [ $hgmajor -eq -1 -o $hgminor -eq -1 -o $hgrev -eq -1 ] ; then
  error "Could not determine Mercurial version of $hgwhere from \"$hgversion\""
fi


# Require
if [ $hgmajor -lt $reqdmajor -o \( $hgmajor -eq $reqdmajor -a $hgminor -lt $reqdminor \) -o \( $hgmajor -eq $reqdmajor -a $hgminor -eq $reqdminor -a $hgrev -lt $reqdrev \) ] ; then
  error "Mercurial version $reqdmajor.$reqdminor.$reqdrev or later is required. $hgwhere is version $hgversion"
fi


# Request
if [ $hgmajor -lt $rqstmajor -o \( $hgmajor -eq $rqstmajor -a $hgminor -lt $rqstminor \) -o \( $hgmajor -eq $rqstmajor -a $hgminor -eq $rqstminor -a $hgrev -lt $rqstrev \) ] ; then
  warning "Mercurial version $rqstmajor.$rqstminor.$rqstrev or later is recommended. $hgwhere is version $hgversion"
fi


# Get clones of all absent nested repositories (harmless if already exist)
if [ ${j9flag} = "true" ] ; then
	patch -p1 < ./openj9/patches/$hgtag/hgforest.patch
	cp ./openj9/hgforest.sh ./common/bin/hgforest.sh

	# clone absent OpenJDK repositories (except hotspot - harmless if already exist)
	sh ./common/bin/hgforest.sh --with-j9 clone || exit $?

	hgoptions=""
	if [ -n  "$hgtag" ]; then
		hgoptions="-u ${hgtag}"
		good_tag="false"

		for tag in ${hgtags} ; do
			if [ ${hgtag} = ${tag} ] ; then
				good_tag="true"
				break
			fi
		done

		if [ ${good_tag} = "false" ] ; then
			error "Invalid revision number: $hgtag. Expected values are: $hgtags"
		fi
	fi

	# roll back OpenJDK components to the given tag
	echo "Update all existing repos with sources from tag: ${hgtag}"
	sh ./common/bin/hgforest.sh --with-j9 update -r ${hgtag}

	# Get clones of OpenJ9 absent repositories
	bash ./openj9/get_j9_source.sh ${j9_repos_options}

	# copy OpenJ9 resources
	cp ./openj9/OpenJ9.mk ./make/
	patch -p1 < ./openj9/patches/${hgtag}/root.patch
	cd langtools
	patch -p1 < ./../openj9/patches/${hgtag}/langtools.patch
	cd ../jdk
	patch -p1 < ./../openj9/patches/${hgtag}/jdk.patch
	cd ..

else
	# Get clones of all OpenJDK absent nested repositories (harmless if already exist)
	sh ./common/bin/hgforest.sh clone || exit $?

	# Update all existing repositories to the latest sources
	sh ./common/bin/hgforest.sh pull -u
fi
