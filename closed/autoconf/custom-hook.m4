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

  # Where are the OpenJ9 sources.
  OPENJ9BINARIES_TOPDIR="$SRC_ROOT/binaries"
  OPENJ9JIT_TOPDIR="$SRC_ROOT/tr.open"
  OPENJ9OMR_TOPDIR="$SRC_ROOT/omr"
  OPENJ9VM_TOPDIR="$SRC_ROOT/j9vm"
  AC_SUBST(OPENJ9BINARIES_TOPDIR)
  AC_SUBST(OPENJ9JIT_TOPDIR)
  AC_SUBST(OPENJ9OMR_TOPDIR)
  AC_SUBST(OPENJ9VM_TOPDIR)

  OPENJ9_PLATFORM_SETUP
])

AC_DEFUN([OPENJ9_PLATFORM_EXTRACT_VARS_FROM_CPU],
[
  # Convert openjdk cpu names to openj9 names
  case "$1" in
    x86_64)
      OPENJ9_CPU=x86-64
      ;;
    powerpc64le)
      OPENJ9_CPU=ppc-64_le
      ;;
    s390x)
      OPENJ9_CPU=s390-64
      ;;
    *)
      AC_MSG_ERROR([unsupported OpenJ9 cpu $1])
      ;;
  esac
])

AC_DEFUN_ONCE([OPENJ9_PLATFORM_SETUP],
[
  OPENJ9_PLATFORM_EXTRACT_VARS_FROM_CPU($build_cpu)
  OPENJ9_PLATFORM="${OPENJDK_BUILD_OS}_${OPENJ9_CPU}_cmprssptrs"

  if test "x$OPENJ9_CPU" = xx86-64; then
    OPENJ9_PLATFORM_CODE=xa64
  elif test "x$OPENJ9_CPU" = xppc-64_le; then
    OPENJ9_PLATFORM_CODE=xl64
    OPENJ9_PLATFORM="${OPENJDK_BUILD_OS}_ppc-64_cmprssptrs_le_gcc"
  elif test "x$OPENJ9_CPU" = xs390-64; then
    OPENJ9_PLATFORM_CODE=xz64
  else
    AC_MSG_ERROR([Unsupported OpenJ9 cpu ${OPENJ9_CPU}, contact support team!])
  fi

  AC_SUBST(OPENJ9_PLATFORM_CODE)
  AC_SUBST(OPENJ9_PLATFORM)
])


AC_DEFUN_ONCE([CUSTOM_LATE_HOOK],
[
  CLOSED_AUTOCONF_DIR="$SRC_ROOT/closed/autoconf"

  # Create the custom-spec.gmk
  AC_CONFIG_FILES([$OUTPUT_ROOT/custom-spec.gmk:$CLOSED_AUTOCONF_DIR/custom-spec.gmk.in])

  # explicitly disable classlist generation
  ENABLE_GENERATE_CLASSLIST="false"
])


