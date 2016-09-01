# Locate make
MAKE := $(shell which make)
#$(info MAKE = $(MAKE))

ROOT_DIR := $(dir $(shell pwd))
#$(info ROOT_DIR = $(ROOT_DIR))

SPEC_FILE := $(shell find $(ROOT_DIR) -name spec.gmk)
$(info Using SPEC_FILE = $(SPEC_FILE))

ifdef SPEC_FILE
	include $(SPEC_FILE)
else
	$(error Missing OpenJDK SPEC file! Run configure first!)
endif


HGTAG_FILE := $(shell find $(ROOT_DIR) -name .hgtags)
#$(info HGTAG_FILE = $(HGTAG_FILE))

TAG := $(lastword $(shell tail -n 1 $(HGTAG_FILE)))
#$(info OpenJDk TAG = $(TAG))

ifdef TAG
	LEN := $(shell echo $(TAG) | wc -m)
endif
#$(info LEN = $(LEN))

ifdef TAG
ifeq ($(LEN),9)
	ID := $(shell echo $(TAG) | tail -c 3)
else
	ID := $(shell echo $(TAG) | tail -c 4)
endif
endif

#$(info ID = $(ID))
JDK_BUILD = $(shell echo $$(( $(ID) + 1 )))
#$(info JDK_BUILD = $(JDK_BUILD))

PRE_MOD_CFG := $(shell if test "$(JDK_BUILD)" -lt "113"; then echo 1; else echo 0; fi)
#$(info PRE_MOD_CFG = $(PRE_MOD_CFG))

ifeq ($(PRE_MOD_CFG), 1) # pre-modules version
 	BOOT_MOD := bootmodules.jimage
	BOOT_MOD_DIR := bootmodules
	EXTRA_PATH := modules/
else
	BOOT_MOD := modules
	BOOT_MOD_DIR := modules-dir
	EXTRA_PATH := 
endif
#$(info BOOT_MOD = $(BOOT_MOD), BOOT_MOD_DIR = $(BOOT_MOD_DIR))

OPENJ9_SRC_DIR := $(shell find $(SRC_ROOT) -maxdepth 1 -type d | grep vm)
#$(info OPENJ9_SRC_DIR = $(OPENJ9_SRC_DIR))

ifndef OPENJ9_SRC_DIR
        $(error Missing OpenJ9 VM sources! Run get_source.sh with j9 option!)
endif

OPENJ9JCL_SRC_DIR := $(shell find $(SRC_ROOT) -maxdepth 1 -type d | grep j9jcl)
#$(info OPENJ9JCL_SRC_DIR = $(OPENJ9JCL_SRC_DIR))

ifndef OPENJ9JCL_SRC_DIR
	$(error Missing OpenJ9 JCL sources! Run get_source.sh with j9 option!)
endif

NUMCPU := $(shell grep -c ^processor /proc/cpuinfo)
#$(info NUMCPU = $(NUMCPU))

override MAKEFLAGS := -j $(NUMCPU)

OPENJ9_IMAGE_DIR := sdk

ALL_TARGETS :=

default: openj9

compile-j9:
	@echo "----------------Compiling OpenJ9 in $(OUTPUT_ROOT)/vm ------------------"
	cp -R $(OPENJ9_SRC_DIR) $(OUTPUT_ROOT)/
	( cd $(OUTPUT_ROOT)/vm && \
		$(MAKE) $(MAKEFLAGS) all )
	@echo "--------------------- Finished compiling OpenJ9 ------------------------"

openj9: compile-j9
	#@echo "---------- Building OpenJ9 image in $(IMAGES_OUTPUTDIR)/$(OPENJ9_IMAGE_DIR) -----------"
	cp -R $(IMAGES_OUTPUTDIR)/jdk $(IMAGES_OUTPUTDIR)/$(OPENJ9_IMAGE_DIR)
	# build pre-compiled bootmodules and copy it to jdk/lib
	( cd $(IMAGES_OUTPUTDIR)/$(OPENJ9_IMAGE_DIR)/lib/$(EXTRA_PATH) && \
		$(BOOT_JDK)/bin/jimage extract $(BOOT_MOD) --dir $(BOOT_MOD_DIR) )
	( cd $(IMAGES_OUTPUTDIR)/$(OPENJ9_IMAGE_DIR)/lib/$(EXTRA_PATH)$(BOOT_MOD_DIR)/java.base && \
		zip -q -r rt.jar . )
	mv $(IMAGES_OUTPUTDIR)/$(OPENJ9_IMAGE_DIR)/lib/$(EXTRA_PATH)$(BOOT_MOD_DIR)/java.base/rt.jar $(IMAGES_OUTPUTDIR)/$(OPENJ9_IMAGE_DIR)/lib
	# modify vm/classlib.properties and copy it to jdk/lib
	@$(SED) -i -e 's/shape=sun/shape=b$(JDK_BUILD)/g' $(OUTPUT_ROOT)/vm/classlib.properties
	@$(SED) -i -e 's/version=1.7/version=1.9/g' $(OUTPUT_ROOT)/vm/classlib.properties
	cp $(OUTPUT_ROOT)/vm/classlib.properties  $(IMAGES_OUTPUTDIR)/$(OPENJ9_IMAGE_DIR)/lib
	# replace j9 libs
	cp -R $(OUTPUT_ROOT)/vm/* $(IMAGES_OUTPUTDIR)/$(OPENJ9_IMAGE_DIR)/lib/amd64/compressedrefs/.
	cp $(IMAGES_OUTPUTDIR)/$(OPENJ9_IMAGE_DIR)/lib/classlib.properties $(IMAGES_OUTPUTDIR)/$(OPENJ9_IMAGE_DIR)/lib/amd64/compressedrefs
	mkdir -p $(IMAGES_OUTPUTDIR)/$(OPENJ9_IMAGE_DIR)/lib/amd64/j9vm
	cp $(IMAGES_OUTPUTDIR)/$(OPENJ9_IMAGE_DIR)/lib/amd64/compressedrefs/redirector/libjvm.so $(IMAGES_OUTPUTDIR)/$(OPENJ9_IMAGE_DIR)/lib/amd64/j9vm
	mkdir -p $(IMAGES_OUTPUTDIR)/$(OPENJ9_IMAGE_DIR)/lib/amd64/compressedrefs/jclSC190
	cp $(IMAGES_OUTPUTDIR)/$(OPENJ9_IMAGE_DIR)/lib/amd64/compressedrefs/J9_JCL/jclSC19B$(JDK_BUILD)/vm.jar $(IMAGES_OUTPUTDIR)/$(OPENJ9_IMAGE_DIR)/lib/amd64/compressedrefs/jclSC190/vm-b$(JDK_BUILD).jar
	cp $(IMAGES_OUTPUTDIR)/$(OPENJ9_IMAGE_DIR)/lib/amd64/compressedrefs/J9TraceFormat.dat $(IMAGES_OUTPUTDIR)/$(OPENJ9_IMAGE_DIR)/lib
	cp $(IMAGES_OUTPUTDIR)/$(OPENJ9_IMAGE_DIR)/lib/amd64/compressedrefs/OMRTraceFormat.dat $(IMAGES_OUTPUTDIR)/$(OPENJ9_IMAGE_DIR)/lib
	cp $(OPENJ9JCL_SRC_DIR)/jcl-4-raw.jar $(IMAGES_OUTPUTDIR)/$(OPENJ9_IMAGE_DIR)/lib
	rm -fdr $(IMAGES_OUTPUTDIR)/$(OPENJ9_IMAGE_DIR)/lib/$(EXTRA_PATH)$(BOOT_MOD_DIR)
	@$(SED) -i -e 's/server KNOWN/j9vm KNOWN/g' $(IMAGES_OUTPUTDIR)/$(OPENJ9_IMAGE_DIR)/lib/amd64/jvm.cfg
	@$(SED) -i -e 's/client IGNORE/hotspot IGNORE/g' $(IMAGES_OUTPUTDIR)/$(OPENJ9_IMAGE_DIR)/lib/amd64/jvm.cfg
	@echo '-classic IGNORE' >> $(IMAGES_OUTPUTDIR)/$(OPENJ9_IMAGE_DIR)/lib/amd64/jvm.cfg
	@echo '-native IGNORE' >> $(IMAGES_OUTPUTDIR)/$(OPENJ9_IMAGE_DIR)/lib/amd64/jvm.cfg
	@echo '-green IGNORE' >> $(IMAGES_OUTPUTDIR)/$(OPENJ9_IMAGE_DIR)/lib/amd64/jvm.cfg
	#( cd $(IMAGES_OUTPUTDIR)/$(OPENJ9_IMAGE_DIR)/lib/$(EXTRA_PATH) && \
	#	$(BOOT_JDK)/bin/jimage extract $(BOOT_MOD) --dir $(BOOT_MOD_DIR) )
	@echo "---------- Finished building OpenJ9 image in $(IMAGES_OUTPUTDIR)/$(OPENJ9_IMAGE_DIR) ------------"

.PHONY: clean-j9
clean-j9:
	( cd $(OUTPUT_ROOT)/vm && \
		$(MAKE) clean )

clean-j9-dist:
	rm -fdr $(IMAGES_OUTPUTDIR)/$(OPENJ9_IMAGE_DIR)
	rm -fdr $(OUTPUT_ROOT)/vm

info:
	@echo In OpenJ9.mk

build-openj9: compile-j9 openj9

ALL_TARGETS := clean-j9-dist openj9

.PHONY: $(ALL_TARGETS)

all: $(ALL_TARGETS)
.PHONY: all

