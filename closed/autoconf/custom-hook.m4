# (c) Copyright IBM Corp. 2017 All Rights Reserved


AC_DEFUN_ONCE([CUSTOM_LATE_HOOK],
[
    CLOSED_AUTOCONF_DIR="$SRC_ROOT/closed/autoconf"

    # Create the custom-spec.gmk
    AC_CONFIG_FILES([$OUTPUT_ROOT/custom-spec.gmk:$CLOSED_AUTOCONF_DIR/custom-spec.gmk.in])
])
