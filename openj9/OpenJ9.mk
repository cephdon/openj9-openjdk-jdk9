# Locate make
MAKE := $(shell which make)
#$(info MAKE = $(MAKE))

$(info BOOT_JDK8 location is set to $(BOOT_JDK8))
$(eval $(shell $(BOOT_JDK8)/bin/java -version))

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

OPENJ9VM_SRC_DIR := $(shell find $(SRC_ROOT) -maxdepth 1 -type d | grep j9vm)
#$(info OPENJ9VM_SRC_DIR = $(OPENJ9VM_SRC_DIR))

ifndef OPENJ9VM_SRC_DIR
	$(error Missing OpenJ9 VM sources! Run get_source.sh with j9 option!)
endif

OPENJ9JIT_SRC_DIR := $(shell find $(SRC_ROOT) -maxdepth 1 -type d | grep tr.open)
#$(info OPENJ9JIT_SRC_DIR = $(OPENJ9JIT_SRC_DIR))

ifndef OPENJ9JIT_SRC_DIR
	$(error Missing OpenJ9 tr.open sources! Run get_source.sh with j9 option!)
endif

OPENJ9OMR_SRC_DIR := $(shell find $(SRC_ROOT) -maxdepth 1 -type d | grep omr)
#$(info OPENJ9OMR_SRC_DIR = $(OPENJ9OMR_SRC_DIR))

ifndef OPENJ9OMR_SRC_DIR
	$(error Missing OpenJ9 OMR sources! Run get_source.sh with j9 option!)
endif

OPENJ9JCL_SRC_DIR := $(shell find $(SRC_ROOT) -maxdepth 1 -type d | grep j9jcl)
#$(info OPENJ9JCL_SRC_DIR = $(OPENJ9JCL_SRC_DIR))

ifndef OPENJ9JCL_SRC_DIR
	$(error Missing OpenJ9 JCL sources! Run get_source.sh with j9 option!)
endif

define \n



endef

define setup.jmod
	@echo
	@echo Processing module $(module)
	@echo
	mkdir -p $(OUTPUT_ROOT)/jcl_workdir/merge/$(module)
	mkdir -p $(OUTPUT_ROOT)/jcl_workdir/modules_root/$(module)
	unzip -q $(OUTPUT_ROOT)/jcl_workdir/merge/sdk/jmods/$(module).jmod -d $(OUTPUT_ROOT)/jcl_workdir/merge/$(module)
	cp -r $(OUTPUT_ROOT)/jcl_workdir/merge/$(module)/classes/* $(OUTPUT_ROOT)/jcl_workdir/modules_root/$(module)/
endef

define recreate.jmod
	@echo
	@echo Processing module $(module)
	@echo
	rm -rf  $(OUTPUT_ROOT)/jcl_workdir/merge/$(module)
	mkdir -p $(OUTPUT_ROOT)/jcl_workdir/merge/$(module)
	mkdir -p $(OUTPUT_ROOT)/jcl_workdir/modules_root/$(module)
	unzip -q $(OUTPUT_ROOT)/jcl_workdir/merge/sdk/jmods/$(module).jmod -d $(OUTPUT_ROOT)/jcl_workdir/merge/$(module)
	$(call create-module-info)
	$(call merge-module-info)
endef

define create-module-info
	@echo
	@echo Recreating $(module)/module-info.java
	@echo
	$(BOOT_JDK)/bin/javap -c -p $(OUTPUT_ROOT)/jcl_workdir/merge/$(module)/classes/module-info.class > $(OUTPUT_ROOT)/jcl_workdir/merge/$(module)/classes/module-info.java2
	sed -i -e 's/\$$/\./g' $(OUTPUT_ROOT)/jcl_workdir/merge/$(module)/classes/module-info.java2
	tail -n +2 $(OUTPUT_ROOT)/jcl_workdir/merge/$(module)/classes/module-info.java2 > $(OUTPUT_ROOT)/jcl_workdir/merge/$(module)/classes/module-info.java
	@rm -rf $(OUTPUT_ROOT)/jcl_workdir/merge/$(module)/classes/module-info.java2
endef

define merge-module-info
	$(BOOT_JDK)/bin/java -cp $(OPENJ9JCL_SRC_DIR)/build.tools/ com.ibm.moduletools.ModuleInfoMerger $(OUTPUT_ROOT)/jcl_workdir/merge/$(module)/classes/module-info.java $(OUTPUT_ROOT)/jcl_workdir/j9jcl/$(module)/module-info_raw.java $(OUTPUT_ROOT)/jcl_workdir/merge/$(module)/classes/module-info.java
	rm -rf $(OUTPUT_ROOT)/jcl_workdir/j9jcl/$(module)/module-info*
	cp -r $(OUTPUT_ROOT)/jcl_workdir/j9jcl/$(module)/* $(OUTPUT_ROOT)/jcl_workdir/merge/$(module)/classes/
	rm -rf $(OUTPUT_ROOT)/jcl_workdir/modules_root/$(module)/*
	cp -r $(OUTPUT_ROOT)/jcl_workdir/merge/$(module)/classes/* $(OUTPUT_ROOT)/jcl_workdir/modules_root/$(module)/
endef

define compile-module-info
	echo Compiling $(module)/module-info.java
	rm -rf $(OUTPUT_ROOT)/jcl_workdir/merge/$(module)/classes/module-info.class
	rm -rf $(OUTPUT_ROOT)/jcl_workdir/modules_root/$(module)/classes/module-info.class
	$(BOOT_JDK)/bin/javac -d $(OUTPUT_ROOT)/jcl_workdir/modules_root -modulesourcepath $(OUTPUT_ROOT)/jcl_workdir/modules_root -modulepath $(OUTPUT_ROOT)/jcl_workdir/modules_root -system none $(OUTPUT_ROOT)/jcl_workdir/modules_root/$(module)/module-info.java
	cp $(OUTPUT_ROOT)/jcl_workdir/modules_root/$(module)/module-info.class $(OUTPUT_ROOT)/jcl_workdir/merge/$(module)/classes/
endef

define create.jmod
	rm -rf $(OUTPUT_ROOT)/jcl_workdir/modules/$(module).jmod
	$(eval vers = --module-version 9-developer)
	$(eval MODULE_DIR_LIST = $(filter-out $(module),$(shell find $(OUTPUT_ROOT)/jcl_workdir/merge/$(module) -maxdepth 1 -type d -exec basename '{}' \; | tr '\n' ' ')))
	$(if $(filter bin,$(MODULE_DIR_LIST)),$(eval bin.dir=--cmds $(OUTPUT_ROOT)/jcl_workdir/merge/$(module)/bin))
	$(if $(filter conf,$(MODULE_DIR_LIST)),$(eval conf.dir=--conf $(OUTPUT_ROOT)/jcl_workdir/merge/$(module)/conf))
	$(if $(filter native,$(MODULE_DIR_LIST)),$(eval native.dir=--libs $(OUTPUT_ROOT)/jcl_workdir/merge/$(module)/native))
	$(BOOT_JDK)/bin/jmod create --class-path $(OUTPUT_ROOT)/jcl_workdir/merge/$(module)/classes $(OUTPUT_ROOT)/jcl_workdir/modules/$(module).jmod $(vers) $(bin.dir) $(native.dir) $(conf.dir)
endef

NUMCPU := $(shell grep -c ^processor /proc/cpuinfo)
#$(info NUMCPU = $(NUMCPU))

override MAKEFLAGS := -j $(NUMCPU)

OPENJ9_IMAGE_DIR := sdk

ALL_TARGETS :=

default: openj9

stage-j9:
	@echo "---------------- Staging OpenJ9 components in $(OUTPUT_ROOT)/vm ------------------"
	rm -rf $(OUTPUT_ROOT)/vm
	mkdir $(OUTPUT_ROOT)/vm
	# actions required to hammer j9vm repo into the 'source.zip' shape
	cp -r $(OPENJ9VM_SRC_DIR)/* $(OUTPUT_ROOT)/vm
	rm -rf $(OUTPUT_ROOT)/vm/8096_*
	cp -r $(OUTPUT_ROOT)/vm/VM_NLS/* $(OUTPUT_ROOT)/vm
	rm -rf $(OUTPUT_ROOT)/vm/VM_NLS
	cp -r $(OUTPUT_ROOT)/vm/VM_Common/* $(OUTPUT_ROOT)/vm
	rm -rf $(OUTPUT_ROOT)/vm/VM_Common
	cp -r $(OUTPUT_ROOT)/vm/VM_Runtime-Tools/* $(OUTPUT_ROOT)/vm
	rm -rf $(OUTPUT_ROOT)/vm/VM_Runtime-Tools
	cp -r $(OPENJ9VM_SRC_DIR)/../tooling/VM_Build-Tools/* $(OUTPUT_ROOT)/vm
	cp -r $(OPENJ9VM_SRC_DIR)/../tooling/VM_Build-Specifications/* $(OUTPUT_ROOT)/vm
	cp $(OPENJ9VM_SRC_DIR)/../binaries/common/ibm/recordio.jar $(OUTPUT_ROOT)/vm/DTFJ\ Core\ File\ Support/
	cp $(OPENJ9VM_SRC_DIR)/../binaries/common/ibm/ibmjzos.jar $(OUTPUT_ROOT)/vm/DTFJ\ Core\ File\ Support/
	mkdir $(OUTPUT_ROOT)/vm/DTFJ_Utils/lib/
	cp $(OPENJ9VM_SRC_DIR)/../binaries/common/third/asm-3.1.jar $(OUTPUT_ROOT)/vm/DTFJ_Utils/lib/
	mkdir $(OUTPUT_ROOT)/vm/J9\ JCL\ Build\ Tools/lib
	cp $(OPENJ9VM_SRC_DIR)/../binaries/vm/third/dbghelp.dll $(OUTPUT_ROOT)/vm/J9\ JCL\ Build\ Tools/lib/
	cp $(OPENJ9VM_SRC_DIR)/../binaries/vm/ibm/buildutils.jar $(OUTPUT_ROOT)/vm/J9\ JCL\ Build\ Tools/lib/buildutils.jar
	cp $(OPENJ9VM_SRC_DIR)/../binaries/vm/ibm/awtMessageStrings.jar $(OUTPUT_ROOT)/vm/J9\ JCL\ Build\ Tools/lib/awtMessageStrings.jar
	cp $(OPENJ9VM_SRC_DIR)/../binaries/vm/ibm/apimarker.jar $(OUTPUT_ROOT)/vm/J9\ JCL\ Build\ Tools/lib/
	cp $(OPENJ9VM_SRC_DIR)/../binaries/vm/ibm/japt.jar $(OUTPUT_ROOT)/vm/J9\ JCL\ Build\ Tools/lib/
	cp $(OPENJ9VM_SRC_DIR)/../binaries/vm/ibm/jpp.jar $(OUTPUT_ROOT)/vm/J9\ JCL\ Build\ Tools/lib/
	cp $(OPENJ9VM_SRC_DIR)/../binaries/vm/ibm/zipit.jar $(OUTPUT_ROOT)/vm/J9\ JCL\ Build\ Tools/lib/
	cp $(OPENJ9VM_SRC_DIR)/../binaries/vm/ibm/jikesbt.jar $(OUTPUT_ROOT)/vm/J9\ JCL\ Build\ Tools/lib/
	cp $(OPENJ9VM_SRC_DIR)/../binaries/vm/ibm/TestGen.jar $(OUTPUT_ROOT)/vm/J9\ JCL\ Build\ Tools/lib/
	cp $(OPENJ9VM_SRC_DIR)/../binaries/vm/ibm/testHarness.jar $(OUTPUT_ROOT)/vm/J9\ JCL\ Build\ Tools/lib/
	cp $(OPENJ9VM_SRC_DIR)/../binaries/vm/ibm/Compiler.jar $(OUTPUT_ROOT)/vm/J9\ JCL\ Build\ Tools/lib/
	cp $(OPENJ9VM_SRC_DIR)/../binaries/vm/ibm/indexer.jar $(OUTPUT_ROOT)/vm/J9\ JCL\ Build\ Tools/lib/
	cp $(OPENJ9VM_SRC_DIR)/../binaries/common/third/junit3.8.2.jar $(OUTPUT_ROOT)/vm/J9\ JCL\ Build\ Tools/lib/
	cp $(OPENJ9VM_SRC_DIR)/../binaries/common/third/junit.jclbuildtools.jar $(OUTPUT_ROOT)/vm/J9\ JCL\ Build\ Tools/lib/JUnit.jar
	cp $(OPENJ9VM_SRC_DIR)/../binaries/common/third/xercesImpl-2.0.2.jar $(OUTPUT_ROOT)/vm/VM_Source-Tools/lib/
	cp $(OPENJ9VM_SRC_DIR)/../binaries/common/third/dom4j-1.6.1.jar $(OUTPUT_ROOT)/vm/VM_Source-Tools/lib/
	cp $(OPENJ9VM_SRC_DIR)/../binaries/common/third/xmlParserAPIs-2.0.2.jar $(OUTPUT_ROOT)/vm/VM_Source-Tools/lib/
	cp $(OPENJ9VM_SRC_DIR)/../binaries/common/third/gnujaxp.jar $(OUTPUT_ROOT)/vm/VM_Source-Tools/lib/
	mkdir -p $(OUTPUT_ROOT)/vm/J9\ JCL\ buildpath/sun190
	mkdir $(OUTPUT_ROOT)/vm/J9\ JCL\ buildpath/sun190B113
	cp $(OPENJ9VM_SRC_DIR)/../binaries/vm/third/rt-compressed.sun190B113.jar $(OUTPUT_ROOT)/vm/J9\ JCL\ buildpath/sun190B113/rt-compressed.jar
	cp $(OPENJ9VM_SRC_DIR)/../binaries/vm/third/rt-compressed.sun190.jar $(OUTPUT_ROOT)/vm/J9\ JCL\ buildpath/sun190/rt-compressed.jar
	cp -r $(OPENJ9VM_SRC_DIR)/../rtctest/com.ibm.jvmti.tests $(OUTPUT_ROOT)/vm/
	# actions required to hammer tr.open repo into the 'source.zip' shape
	cp -r $(OPENJ9JIT_SRC_DIR)/* $(OUTPUT_ROOT)/vm/tr.source/
	echo "#define TR_LEVEL_NAME \"`git -C $(OPENJ9JIT_SRC_DIR) describe --tags`\"" > $(OUTPUT_ROOT)/vm/tr.source/jit.version
	# actions required to hammer OMR repo into the 'source.zip' shape
	mkdir $(OUTPUT_ROOT)/vm/omr
	cp -r $(OPENJ9OMR_SRC_DIR)/* $(OUTPUT_ROOT)/vm/omr/
	echo "#define OMR_VERSION_STRING \"`git -C $(OPENJ9OMR_SRC_DIR) rev-parse --short HEAD`\"" > $(OUTPUT_ROOT)/vm/omr/OMR_VERSION_STRING
	@echo "---------------- Finished staging OpenJ9 ------------------------"

run-preprocessors-j9:
	@echo "---------------- Running OpenJ9 preprocessors ------------------------"
	cd $(OUTPUT_ROOT)/vm
	# checkSpec copya2e configure uma j9vm_sha rpcgen tracing nls hooktool constantpool ddr
	sed -i -e 's/1.5/1.8/g' $(OUTPUT_ROOT)/vm/VM_Source-Tools/buildj9tools.mk
	(cd $(OUTPUT_ROOT)/vm && make -f buildtools.mk SPEC=linux_x86-64 JAVA_HOME=$(BOOT_JDK) buildtools)
	(cd $(OUTPUT_ROOT)/vm && make -f buildtools.mk SPEC=linux_x86-64 checkSpec)
	(cd $(OUTPUT_ROOT)/vm && make -f buildtools.mk SPEC=linux_x86-64 copya2e)
	(cd $(OUTPUT_ROOT)/vm && make -f buildtools.mk SPEC=linux_x86-64 configure)
	(cd $(OUTPUT_ROOT)/vm && make -f buildtools.mk SPEC=linux_x86-64 BUILD_ID=123456 UMA_OPTIONS_EXTRA="-buildDate 20160927" uma)
	$(eval J9VM_SHA=$(shell git -C $(OPENJ9VM_SRC_DIR) rev-parse --short HEAD))
	@sed -i -e 's/developer.compile/$(J9VM_SHA)/g' $(OUTPUT_ROOT)/vm/include/j9version.h
	@echo J9VM version string set to : $(J9VM_SHA)
	(cd $(OUTPUT_ROOT)/vm && make -f buildtools.mk SPEC=linux_x86-64 tracing)
	(cd $(OUTPUT_ROOT)/vm && make -f buildtools.mk SPEC=linux_x86-64 nls)
	(cd $(OUTPUT_ROOT)/vm && make -f buildtools.mk SPEC=linux_x86-64 JAVA_HOME=$(BOOT_JDK8) hooktool)
	(cd $(OUTPUT_ROOT)/vm && make -f buildtools.mk SPEC=linux_x86-64 constantpool)
	(cd $(OUTPUT_ROOT)/vm && make -f buildtools.mk SPEC=linux_x86-64 ddr)
	sed -i -e 's/gcc-4.6/gcc/g' $(OUTPUT_ROOT)/vm/makelib/mkconstants.mk
	sed -i -e 's/O3 -fno-strict-aliasing/O0 -Wno-format -Wno-unused-result -fno-strict-aliasing -fno-stack-protector/g' $(OUTPUT_ROOT)/vm/makelib/targets.mk
	# generate RAS binaries - PROBLEM: need to fix these to work with new sdk release
	sed -i -e 's/1.5\"/1.8\"/g' $(OUTPUT_ROOT)/vm/RAS_Binaries/build.xml
	ant -lib $(OUTPUT_ROOT)/vm/VM_Source-Tools/lib/om.jar -f $(OUTPUT_ROOT)/vm/RAS_Binaries/build.xml -Dwith-boot-jdk=$(BOOT_JDK)
	#generate j8 cuda jar
	ant -verbose -f "$(OUTPUT_ROOT)/vm/J9 JCL/cuda4j.xml" -Djvm.version=28 -Dspec.level=1.8 -Dsource=. -Djavabin=$(BOOT_JDK)/bin/ all
	#generate j9 cuda jar
	ant -verbose -f "$(OUTPUT_ROOT)/vm/J9 JCL/cuda4j.xml" -Djvm.version=29 -Dspec.level=1.8 -Dsource=. -Djavabin=$(BOOT_JDK)/bin/ all
	#generate j9 modularity cuda jar
	ant -verbose -f "$(OUTPUT_ROOT)/vm/J9 JCL/cuda4j.xml" -Djvm.version=28 -Dspec.level=1.9 -Dsource=. -Djavabin=$(BOOT_JDK)/bin/ all
	ant -verbose -f "$(OUTPUT_ROOT)/vm/JCL Ant Build/jcl_build.xml" -Djob.buildId= -Dspec.level=1.9 -Djpp.config=SIDECAR19-DAA -Dcompile.bcp=sun190 -Djpp.dirname=jclSC190-DAA -Dsource=$(OUTPUT_ROOT)/vm -Djavabin=$(BOOT_JDK)/bin/ -Dbuild.root=$(OUTPUT_ROOT)/vm all
	ant -verbose -f "$(OUTPUT_ROOT)/vm/JCL Ant Build/jcl_build.xml" -Djob.buildId= -Dspec.level=1.9 -Djpp.config=SIDECAR19_MODULAR-SE -Dcompile.bcp=sun190B113 -Djpp.dirname=jclSC19Modular -Dsource=$(OUTPUT_ROOT)/vm -Djavabin=$(BOOT_JDK)/bin/ -Dbuild.root=$(OUTPUT_ROOT)/vm all
	@echo "---------------- Finished OpenJ9 preprocessors ------------------------"

.PARALLEL compile-j9:
	@echo "----------------Compiling OpenJ9 in $(OUTPUT_ROOT)/vm ------------------"
	(cd $(OUTPUT_ROOT)/vm && $(MAKE) $(MAKEFLAGS) all)
	@echo "--------------------- Finished compiling OpenJ9 ------------------------"

.NOTPARALLEL openj9: stage-j9 run-preprocessors-j9 compile-j9 setup.j9jcl setup.jmods rebuild.j9.jmods compile.module.java rebuild.jmods compose-j9

setup.j9jcl:
	@echo "---------- Building OpenJ9 image in $(IMAGES_OUTPUTDIR)/$(OPENJ9_IMAGE_DIR) -----------"
	rm -rf $(OUTPUT_ROOT)/jcl_workdir/merge
	rm -rf $(OUTPUT_ROOT)/jcl_workdir/modules
	rm -rf $(OUTPUT_ROOT)/jcl_workdir/j9jcl
	rm -rf $(OUTPUT_ROOT)/jcl_workdir/modules_root/
	cp -R $(IMAGES_OUTPUTDIR)/jdk $(IMAGES_OUTPUTDIR)/$(OPENJ9_IMAGE_DIR)
	chmod -R 775 $(IMAGES_OUTPUTDIR)/$(OPENJ9_IMAGE_DIR)
	mkdir -p $(OUTPUT_ROOT)/jcl_workdir/merge/
	mkdir -p $(OUTPUT_ROOT)/jcl_workdir/modules/
	cp -R $(IMAGES_OUTPUTDIR)/$(OPENJ9_IMAGE_DIR) $(OUTPUT_ROOT)/jcl_workdir/merge/sdk/
	unzip -qo "$(OUTPUT_ROOT)/vm/J9 JCL/cuda4j_j9_modular.jar" -d $(OUTPUT_ROOT)/jcl_workdir/j9jcl/
	unzip -qo $(OUTPUT_ROOT)/vm/build/j9jcl/source/ive/lib/jclSC19Modular/classes-vm.zip -d $(OUTPUT_ROOT)/jcl_workdir/j9jcl/
	unzip -qo $(OUTPUT_ROOT)/vm/build/j9jcl/source/ive/lib/jclSC190-DAA/classes-vm.zip -d $(OUTPUT_ROOT)/jcl_workdir/j9jcl/java.base/ "com/ibm/dataaccess/*"
	unzip -qo $(OPENJ9VM_SRC_DIR)/../tooling/jvmbuild_scripts/jcl-4-raw.jar -d $(OUTPUT_ROOT)/jcl_workdir/j9jcl/java.base/
	rm -rf $(OUTPUT_ROOT)/jcl_workdir/j9jcl/META-INF

setup.jmods:
	$(eval override MODULE_LIST = $(shell find $(IMAGES_OUTPUTDIR)/$(OPENJ9_IMAGE_DIR)/jmods  -name "*.jmod" -exec basename '{}' .jmod \; | tr '\n' ' '))
	$(foreach module, $(MODULE_LIST), $(call setup.jmod ) $(\n))

rebuild.j9.jmods:
	$(eval override J9_MODULE_LIST = $(filter-out j9jcl,$(shell find $(OUTPUT_ROOT)/jcl_workdir/j9jcl/ -maxdepth 1 -type d -exec basename '{}' \; | tr '\n' ' ')))
	$(foreach module, $(J9_MODULE_LIST), $(call recreate.jmod) $(\n))

compile.module.java:
	$(foreach module, $(J9_MODULE_LIST), $(call compile-module-info) $(\n))

rebuild.jmods:
	$(eval override MODULE_LIST = $(filter-out modules_root,$(shell find $(OUTPUT_ROOT)/jcl_workdir/modules_root/ -maxdepth 1 -type d -exec basename '{}' \; | tr '\n' ' ')))
	$(foreach module, $(MODULE_LIST), $(call create.jmod) $(\n))

compose-j9:
	$(eval override MODULE_LIST = $(shell find $(OUTPUT_ROOT)/jcl_workdir/modules -name "*.jmod" -exec basename '{}' .jmod \; | tr '\n' ' '))
	$(BOOT_JDK)/bin/jlink --modulepath $(OUTPUT_ROOT)/jcl_workdir/modules --addmods $(MODULE_LIST) --output $(OUTPUT_ROOT)/jcl_workdir/merge/updated_module
	cp $(IMAGES_OUTPUTDIR)/$(OPENJ9_IMAGE_DIR)/lib/modules $(IMAGES_OUTPUTDIR)/$(OPENJ9_IMAGE_DIR)/lib/modules.org
	cp $(OUTPUT_ROOT)/jcl_workdir/merge/updated_module/lib/modules $(IMAGES_OUTPUTDIR)/$(OPENJ9_IMAGE_DIR)/lib/
	$(SED) -i -e 's/shape=sun/shape=b$(JDK_BUILD)/g' $(OUTPUT_ROOT)/vm/classlib.properties
	$(SED) -i -e 's/version=1.7/version=1.9/g' $(OUTPUT_ROOT)/vm/classlib.properties
	cp $(OUTPUT_ROOT)/vm/classlib.properties  $(IMAGES_OUTPUTDIR)/$(OPENJ9_IMAGE_DIR)/lib
	cp -R $(OUTPUT_ROOT)/vm/* $(IMAGES_OUTPUTDIR)/$(OPENJ9_IMAGE_DIR)/lib/amd64/compressedrefs/.
	cp $(IMAGES_OUTPUTDIR)/$(OPENJ9_IMAGE_DIR)/lib/classlib.properties $(IMAGES_OUTPUTDIR)/$(OPENJ9_IMAGE_DIR)/lib/amd64/compressedrefs
	mkdir -p $(IMAGES_OUTPUTDIR)/$(OPENJ9_IMAGE_DIR)/lib/amd64/j9vm
	cp $(IMAGES_OUTPUTDIR)/$(OPENJ9_IMAGE_DIR)/lib/amd64/compressedrefs/redirector/libjvm.so $(IMAGES_OUTPUTDIR)/$(OPENJ9_IMAGE_DIR)/lib/amd64/j9vm
	cp $(IMAGES_OUTPUTDIR)/$(OPENJ9_IMAGE_DIR)/lib/amd64/compressedrefs/J9TraceFormat.dat $(IMAGES_OUTPUTDIR)/$(OPENJ9_IMAGE_DIR)/lib
	cp $(IMAGES_OUTPUTDIR)/$(OPENJ9_IMAGE_DIR)/lib/amd64/compressedrefs/OMRTraceFormat.dat $(IMAGES_OUTPUTDIR)/$(OPENJ9_IMAGE_DIR)/lib

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

