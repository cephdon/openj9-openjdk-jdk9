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
	if expr 1 + $field >/dev/null 2>&1 ; then
		echo $field
	else
		echo -1
	fi
}

usage() {
	echo "Usage: $0 [-h|--help] [-r|--revision=<tag>] [-j9|--with-j9] [... other j9 options] [-parallel=<true|false>]"
	echo "where:"
	echo "  -h|--help         print this help, then exit"
	echo "  -r|--revision     check out a given tag: e.g. jdk-9+162"
	echo "  -j9|--with-j9     get the OpenJ9 latest sources"
	echo " "
	echo " other j9 options (used only with -j9|--with-j9 option):"
	echo "  -j9vm-repo        the OpenJ9/vm repository url: git002@gitlab-polyglot.hursley.ibm.com:j9/j9vm.git"
	echo "                    or <user>@gitlab-polyglot.hursley.ibm.com:<namespace>/j9vm.git"
	echo "  -j9vm-branch      the OpenJ9/vm git branch: master"
	echo "  -j9vmSHA          a commit SHA for the j9vm repository"
	echo "  -omr-repo         the OpenJ9/omr repository url: git002@gitlab-polyglot.hursley.ibm.com:omr/omr.git"
	echo "                    or <user>@gitlab-polyglot.hursley.ibm.com:<namespace>/omr.git"
	echo "  -omr-branch       the OpenJ9/omr git branch: java-master"
	echo "  -omrSHA           a commit SHA for the omr repository"
	echo "  -binaries-repo    the OpenJ9/binaries repository url: git002@gitlab-polyglot.hursley.ibm.com:j9/binaries.git"
	echo "                    or <user>@gitlab-polyglot.hursley.ibm.com:<namespace>/binaries.git"
	echo "  -binaries-branch  the OpenJ9/binaries git branch: master"
	echo "  -binariesSHA      a commit SHA for the binaries repository"
	echo "  -jit-repo         the OpenJ9/jit repository url: git002@gitlab-polyglot.hursley.ibm.com:jit/tr.open.git"
	echo "                    or <user>@gitlab-polyglot.hursley.ibm.com:<namespace>/tr.open.git "
	echo "  -jit-branch       the OpenJ9/jit git branch: java-master"
	echo "  -jitSHA           a commit SHA for the tr.open repository"
	echo "  -parallel         (boolean) if 'true' then the clone j9 repository commands run in parallel, default is false"
	echo " "
	exit 1
}

j9flag=false
tag="jdk-9+162"

for i in "$@" ; do
	case $i in
		-h | --help )
			usage
			;;

		-j9 | --with-j9 )
			j9flag=true
			;;

		-j9vm-repo=* | -j9vm-branch=* | -omr-repo=* | -omr-branch=* | -binaries-repo=* | -binaries-branch=* | -jit-repo=* |-jit-branch=* )
			j9options="${j9options} ${i}"
			;;

		-j9vmSHA=* | -omrSHA=* | -binariesSHA=* | -jitSHA=* )
			j9options="${j9options} ${i}"
			;;

		-parallel=* )
			j9options="${j9options} ${i}"
			;;

		-r=* | --revision=* )
			tag="${i#*=}"
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

# expected OpenJDK tags
hgtags="jdk-9+162"

if [ -n "$tag" ]; then
	good_tag="false"

	for hgtag in ${hgtags} ; do
		if [ ${hgtag} = ${tag} ] ; then
			good_tag="true"
			break
		fi
	done

	if [ ${good_tag} = "false" ] ; then
		error "Invalid revision number: $tag. Expected values are: $hgtags"
	fi
fi

# Version check

hg_version_check() {
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
}

if [ "${j9flag}" = true ] ; then
	# Get clones of OpenJ9 absent repositories
	bash openj9/get_j9_source.sh ${j9options}
else
	hg_version_check

	if [ -d hotspot ] ; then
		# update hotspot
		echo
		echo "Update hotspot source"
		echo

		cd hotspot
		hg pull default
		hg update -r ${tag} || exit $?
		cd -
	else
		# Get OpenJDK source
		echo
		echo "Clone hotspot"
		echo
		hg clone -r ${tag} http://hg.openjdk.java.net/jdk9/jdk9/hotspot || exit $?
	fi

	git checkout tags/${tag} || exit $?
fi
