# (c) Copyright IBM Corp. 2017 All Rights Reserved

AC_DEFUN_ONCE([CUSTOM_EARLY_HOOK],
[
  # Check whether --with-j9 was given.
  BUILD_OPENJ9=false
  AC_ARG_WITH(j9, [AS_HELP_STRING([--with-j9], [Build J9 VM sources])])
  if test "x$with-j9" != x; then
  	if ! (test -d $SRC_ROOT/j9vm); then
  	  AC_MSG_ERROR(["Cannot locate the path to OpenJ9 sources!"])
 	fi
  	BUILD_OPENJ9=true
  fi
  
  AC_SUBST(BUILD_OPENJ9)

  if test "x$with-j9" != x; then
    JAVA_BASE_LDFLAGS="${JAVA_BASE_LDFLAGS} -L\$(SUPPORT_OUTPUTDIR)/../vm"
  fi

  if test "x$with-j9" != x; then
    OPENJDK_BUILD_JAVA_BASE_LDFLAGS="${OPENJDK_BUILD_JAVA_BASE_LDFLAGS} -L\$(SUPPORT_OUTPUTDIR)/../vm"
  fi
])


AC_DEFUN_ONCE([CUSTOM_LATE_HOOK],
[
  CLOSED_AUTOCONF_DIR="$SRC_ROOT/closed/autoconf"

  # Create the custom-spec.gmk
  AC_CONFIG_FILES([$OUTPUT_ROOT/custom-spec.gmk:$CLOSED_AUTOCONF_DIR/custom-spec.gmk.in])
])


