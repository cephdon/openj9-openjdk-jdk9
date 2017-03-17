ifeq ($(wildcard $(SPEC)),)
  $(error OpenJ9.mk needs SPEC set to a proper spec.gmk)
endif
include $(SPEC)

ifeq ($(OPENJDK_TARGET_BUNDLE_PLATFORM),linux-x64)
        export J9_PLATFORM=linux_x86-64
else ifeq ($(OPENJDK_TARGET_BUNDLE_PLATFORM),linux-ppc64le)
        export J9_PLATFORM=linux_ppc-64_le
else ifeq ($(OPENJDK_TARGET_BUNDLE_PLATFORM),linux-s390x)
        export J9_PLATFORM=linux_390-64
else
        $(error "Unsupported platform, contact support team: $(OPENJDK_TARGET_BUNDLE_PLATFORM)")
endif
$(info J9_PLATFORM set to $(J9_PLATFORM))

JDK_BUILD = $(lastword $(subst 9+, ,$(shell hg id | awk '{print $$2}')))
OPENJ9VM_SRC_DIR := $(SRC_ROOT)/j9vm
OPENJ9JIT_SRC_DIR := $(SRC_ROOT)/tr.open
OPENJ9OMR_SRC_DIR := $(SRC_ROOT)/omr
OPENJ9BINARIES_DIR := $(SRC_ROOT)/binaries

define \n



endef

define recompilation
	$(BUILD_JAVAP) -c -p $(BUILD_JDK)/modules/$(module)/module-info.class > $(BUILD_JDK)/modules/$(module)/module-info.java.temp
	sed -i -e 's/\$$/\./g' $(BUILD_JDK)/modules/$(module)/module-info.java.temp
	tail -n +2 $(BUILD_JDK)/modules/$(module)/module-info.java.temp > $(BUILD_JDK)/modules/$(module)/module-info.java
	echo $(BUILD_JDK)/modules/$(module)/module-info.java >> $(BUILD_JDK)/../moduleinfo.list
endef

define copy-ibm-specific
	rm -rf $(BUILD_JDK)/modules/$(module)
	mkdir -p $(BUILD_JDK)/modules/$(module)
	cp -rf $(OUTPUT_ROOT)/j9classes/$(module)/* $(BUILD_JDK)/modules/$(module)/.
	echo $(BUILD_JDK)/modules/$(module)/module-info.java >> $(BUILD_JDK)/../moduleinfo.list
endef

define merge-module-info
	cp -rf $(OUTPUT_ROOT)/j9classes/$(module)/* $(BUILD_JDK)/modules/$(module)/.
	mv $(BUILD_JDK)/modules/$(module)/module-info.java $(BUILD_JDK)/modules/$(module)/module-info.java.j9
	$(BUILD_JAVAP) -c -p $(BUILD_JDK)/modules/$(module)/module-info.class > $(BUILD_JDK)/modules/$(module)/module-info.java.temp
	sed -i -e 's/\$$/\./g' $(BUILD_JDK)/modules/$(module)/module-info.java.temp
	tail -n +2 $(BUILD_JDK)/modules/$(module)/module-info.java.temp > $(BUILD_JDK)/modules/$(module)/module-info.java.oracle
	$(BUILD_JAVA) -DusePublicKeyword=false -cp $(OUTPUT_ROOT)/vm/sourcetools/lib/ com.ibm.moduletools.ModuleInfoMerger $(BUILD_JDK)/modules/$(module)/module-info.java.oracle $(BUILD_JDK)/modules/$(module)/module-info.java.j9 $(BUILD_JDK)/modules/$(module)/module-info.java
	echo $(BUILD_JDK)/modules/$(module)/module-info.java >> $(BUILD_JDK)/../moduleinfo.list
endef

define compile-module-info
	$(BUILD_JAVAC) -source 9 -target 9 -encoding ascii -d $(BUILD_JDK)/modules --module-source-path $(BUILD_JDK)/modules --module-path $(BUILD_JDK)/modules --system none @$(BUILD_JDK)/../moduleinfo.list
endef

# Find recursively in directory $1 all of the files with given extension $2.
#
# Parameters:
#	param 1 is the name of the directory to search
#	parem 2 is the file extension to search in given directory: e.g *.java
# 
define findFiles
	$(foreach i,$(wildcard $1*),$(call findAllFiles,$i/,$2)) $(wildcard $1$2)
endef

# Finds recursively all of the files with given extension in the given source 
# directories and outputs them to a file. 
#
# Parameters:
# 	param 1 is a space separated list of source directories to search
#	param 2 is the extension of the file to look up in the source directories
#	param 3 is the name of the output file
# 
# Usage: $(call cacheFile, dir1 dir2, *.java, /path/to/sources.txt
#
define cacheFiles
	$(foreach d, $1, @echo $(strip $(call findFiles, $d, $2)) >> $3)
endef

NUMCPU := $(shell grep -c ^processor /proc/cpuinfo)
#$(info NUMCPU = $(NUMCPU))

override MAKEFLAGS := -j $(NUMCPU)

.PHONY: clean-j9 clean-j9-dist compose-j9 create-jmod prepare-jmod setup-j9jcl compile-j9 stage-j9 openj9 run-preprocessors-j9 build-j9 setup-j9jcl-pre-jcl merge_module compose compose-buildjvm 
.NOTPARALLEL:
build-j9: stage-j9 run-preprocessors-j9 compile-j9 setup-j9jcl-pre-jcl

stage-j9:
	@echo "---------------- Staging OpenJ9 components in $(OUTPUT_ROOT)/vm ------------------"
	rm -rf $(OUTPUT_ROOT)/vm
	mkdir $(OUTPUT_ROOT)/vm
	# actions required to hammer j9vm repo into the 'source.zip' shape
	cp -r $(OPENJ9VM_SRC_DIR)/* $(OUTPUT_ROOT)/vm
	cp -r $(OUTPUT_ROOT)/vm/runtime/* $(OUTPUT_ROOT)/vm
	rm -rf $(OUTPUT_ROOT)/vm/runtime
	mkdir -p $(OUTPUT_ROOT)/vm/buildtools/extract_structures/linux_x86/
	cp $(OPENJ9BINARIES_DIR)/vm/ibm/extract_structures $(OUTPUT_ROOT)/vm/buildtools/extract_structures/linux_x86/
	cp $(OPENJ9BINARIES_DIR)/common/ibm/uma.jar $(OUTPUT_ROOT)/vm/buildtools/
	cp $(OPENJ9BINARIES_DIR)/common/third/freemarker.jar $(OUTPUT_ROOT)/vm/buildtools/
	cp $(OPENJ9BINARIES_DIR)/vm/ibm/j9ddr-autoblob.jar $(OUTPUT_ROOT)/vm/buildtools/
	cp -r $(OPENJ9VM_SRC_DIR)/buildspecs $(OUTPUT_ROOT)/vm
	@sed -i -e 's/, com.ibm.sharedclasses//g' '$(OUTPUT_ROOT)/vm/jcl/src/java.base/module-info.java'
	@sed -i -e '/sharedclasses/d' '$(OUTPUT_ROOT)/vm/jcl/src/java.base/module-info.java'
	@sed -i -e '/com.ibm.cuda/d' '$(OUTPUT_ROOT)/vm/jcl/src/java.base/module-info.java'
	@sed -i -e '/openj9.gpu/d' '$(OUTPUT_ROOT)/vm/jcl/src/java.base/module-info.java'
	@sed -i -e '/dtfj/d' '$(OUTPUT_ROOT)/vm/jcl/src/java.base/module-info.java'
	@sed -i -e '/sharedclasses/d' '$(OUTPUT_ROOT)/vm/jcl/src/java.management/module-info.java'
	mkdir $(OUTPUT_ROOT)/vm/sourcetools/J9_JCL_Build_Tools/lib
	cp $(OPENJ9BINARIES_DIR)/vm/third/dbghelp.dll $(OUTPUT_ROOT)/vm/sourcetools/J9_JCL_Build_Tools/lib/
	cp $(OPENJ9BINARIES_DIR)/vm/ibm/buildutils.jar $(OUTPUT_ROOT)/vm/sourcetools/J9_JCL_Build_Tools/lib/buildutils.jar
	cp $(OPENJ9BINARIES_DIR)/vm/ibm/awtMessageStrings.jar $(OUTPUT_ROOT)/vm/sourcetools/J9_JCL_Build_Tools/lib/awtMessageStrings.jar
	cp $(OPENJ9BINARIES_DIR)/vm/ibm/apimarker.jar $(OUTPUT_ROOT)/vm/sourcetools/J9_JCL_Build_Tools/lib/
	cp $(OPENJ9BINARIES_DIR)/vm/ibm/japt.jar $(OUTPUT_ROOT)/vm/sourcetools/J9_JCL_Build_Tools/lib/
	cp $(OPENJ9BINARIES_DIR)/vm/ibm/jpp.jar $(OUTPUT_ROOT)/vm/sourcetools/J9_JCL_Build_Tools/lib/
	cp $(OPENJ9BINARIES_DIR)/vm/ibm/zipit.jar $(OUTPUT_ROOT)/vm/sourcetools/J9_JCL_Build_Tools/lib/
	cp $(OPENJ9BINARIES_DIR)/vm/ibm/jikesbt.jar $(OUTPUT_ROOT)/vm/sourcetools/J9_JCL_Build_Tools/lib/
	cp $(OPENJ9BINARIES_DIR)/vm/ibm/TestGen.jar $(OUTPUT_ROOT)/vm/sourcetools/J9_JCL_Build_Tools/lib/
	cp $(OPENJ9BINARIES_DIR)/vm/ibm/Compiler.jar $(OUTPUT_ROOT)/vm/sourcetools/J9_JCL_Build_Tools/lib/
	cp $(OPENJ9BINARIES_DIR)/vm/ibm/indexer.jar $(OUTPUT_ROOT)/vm/sourcetools/J9_JCL_Build_Tools/lib/
	cp $(OPENJ9BINARIES_DIR)/common/third/junit3.8.2.jar $(OUTPUT_ROOT)/vm/sourcetools/J9_JCL_Build_Tools/lib/
	cp $(OPENJ9BINARIES_DIR)/common/third/junit.jclbuildtools.jar $(OUTPUT_ROOT)/vm/sourcetools/J9_JCL_Build_Tools/lib/JUnit.jar
	cp $(OPENJ9BINARIES_DIR)/common/third/xercesImpl.jar $(OUTPUT_ROOT)/vm/sourcetools/lib/
	cp $(OPENJ9BINARIES_DIR)/common/third/dom4j-1.6.1.jar $(OUTPUT_ROOT)/vm/sourcetools/lib/
	cp $(OPENJ9BINARIES_DIR)/common/third/xmlParserAPIs-2.0.2.jar $(OUTPUT_ROOT)/vm/sourcetools/lib/
	cp $(OPENJ9BINARIES_DIR)/common/third/gnujaxp.jar $(OUTPUT_ROOT)/vm/sourcetools/lib/
	mkdir -p $(OUTPUT_ROOT)/vm/sourcetools/J9_JCL_buildpath/sun190
	cp $(OPENJ9BINARIES_DIR)/vm/third/rt-compressed.sun190.jar $(OUTPUT_ROOT)/vm/sourcetools/J9_JCL_buildpath/sun190/rt-compressed.jar
	# actions required to hammer tr.open repo into the 'source.zip' shape
	cp -r $(OPENJ9JIT_SRC_DIR)/* $(OUTPUT_ROOT)/vm/tr.source/
	echo "#define TR_LEVEL_NAME \"`git -C $(OPENJ9JIT_SRC_DIR) describe --tags`\"" > $(OUTPUT_ROOT)/vm/tr.source/jit.version
	# actions required to hammer OMR repo into the 'source.zip' shape
	mkdir $(OUTPUT_ROOT)/vm/omr
	cp -r $(OPENJ9OMR_SRC_DIR)/* $(OUTPUT_ROOT)/vm/omr/
	echo "#define OMR_VERSION_STRING \"`git -C $(OPENJ9OMR_SRC_DIR) rev-parse --short HEAD`\"" > $(OUTPUT_ROOT)/vm/omr/OMR_VERSION_STRING
	@echo "---------------- Finished staging OpenJ9 ------------------------"

run-preprocessors-j9: stage-j9
	@echo "---------------- Running OpenJ9 preprocessors ------------------------"
	cd $(OUTPUT_ROOT)/vm
	$(BOOT_JDK)/bin/javac $(OUTPUT_ROOT)/vm/sourcetools/J9_JCL_Build_Tools/src/com/ibm/moduletools/ModuleInfoMerger.java -d $(OUTPUT_ROOT)/vm/sourcetools/lib
	(export BOOT_JDK=$(BOOT_JDK) && cd $(OUTPUT_ROOT)/vm && $(MAKE) $(MAKEFLAGS) -f buildtools.mk SPEC=$(J9_PLATFORM) JAVA_HOME=$(BOOT_JDK) BUILD_ID=000000 UMA_OPTIONS_EXTRA="-buildDate $(shell date +'%Y%m%d')" tools)
	$(eval J9VM_SHA=$(shell git -C $(OPENJ9VM_SRC_DIR) rev-parse --short HEAD))
	@sed -i -e 's/developer.compile/$(J9VM_SHA)/g' $(OUTPUT_ROOT)/vm/include/j9version.h
	@echo J9VM version string set to : $(J9VM_SHA)
	sed -i -e 's/gcc-4.6/gcc/g' $(OUTPUT_ROOT)/vm/makelib/mkconstants.mk
	sed -i -e 's/O3 -fno-strict-aliasing/O0 -Wno-format -Wno-unused-result -fno-strict-aliasing -fno-stack-protector/g' $(OUTPUT_ROOT)/vm/makelib/targets.mk
	(cd $(OUTPUT_ROOT)/vm/jcl/ && $(MAKE) -f cuda4j.mk JVM_VERSION=28 SPEC_LEVEL=1.8 BUILD_ID=$(shell date +'%N') BUILD_ROOT=$(OUTPUT_ROOT)/vm JAVA_BIN=$(BOOT_JDK)/bin WORKSPACE=$(OUTPUT_ROOT)/vm)
	$(MAKE) $(MAKEFLAGS) -f $(OUTPUT_ROOT)/vm/jcl/jcl_build.mk IBMJZOS_JAR=$(OPENJ9BINARIES_DIR)/common/ibm/ibmjzos.jar SPEC_LEVEL=1.9 JPP_CONFIG=SIDECAR19-SE BUILD_ID=$(shell date +'%N') COMPILER_BCP=sun190 JPP_DIRNAME=jclSC19 JAVA_BIN=$(BOOT_JDK)/bin/ BUILD_ROOT=$(OUTPUT_ROOT)/vm NVCC=/usr/local/cuda/bin/nvcc WORKSPACE=$(OUTPUT_ROOT)/vm 
	@echo "---------------- Finished OpenJ9 preprocessors ------------------------"

compile-j9: run-preprocessors-j9 
	@echo "----------------Compiling OpenJ9 in $(OUTPUT_ROOT)/vm ------------------"
	(cd $(OUTPUT_ROOT)/vm && $(MAKE) $(MAKEFLAGS) all)
	@echo "--------------------- Finished compiling OpenJ9 ------------------------"

setup-j9jcl-pre-jcl: 
	@echo "----------------------Extract vm.jar and jcl-4-raw.jar ------------"
	rm -rf $(OUTPUT_ROOT)/j9classes
	mkdir -p $(OUTPUT_ROOT)/j9classes
	unzip -qo $(OUTPUT_ROOT)/vm/build/j9jcl/source/ive/lib/jclSC19/classes-vm.zip -d $(OUTPUT_ROOT)/j9classes
	unzip -qo $(OPENJ9VM_SRC_DIR)/../tooling/jvmbuild_scripts/jcl-4-raw.jar -d $(OUTPUT_ROOT)/j9classes/java.base
	mkdir -p $(OUTPUT_ROOT)/support/modules_libs/java.base/server/
	cp $(OUTPUT_ROOT)/vm/j9vm_b156/libjvm.so $(OUTPUT_ROOT)/support/modules_libs/java.base/server/
	cp $(OUTPUT_ROOT)/vm/libjsig.so $(OUTPUT_ROOT)/support/modules_libs/java.base/

compose-buildjvm:
	cp $(OPENJ9VM_SRC_DIR)/../tooling/jvmbuild_scripts/jvm.cfg $(OUTPUT_ROOT)/jdk/lib/
	$(SED) -i -e 's/shape=vm.shape/shape=b$(JDK_BUILD)/g' $(OUTPUT_ROOT)/vm/classlib.properties
	$(MKDIR) -p $(OUTPUT_ROOT)/jdk/lib/compressedrefs/
	cp -R $(OUTPUT_ROOT)/vm/*.so $(OUTPUT_ROOT)/jdk/lib/compressedrefs/
	cp $(OUTPUT_ROOT)/vm/J9TraceFormat.dat $(OUTPUT_ROOT)/jdk/lib/
	cp $(OUTPUT_ROOT)/vm/OMRTraceFormat.dat $(OUTPUT_ROOT)/jdk/lib/
	cp -R $(OUTPUT_ROOT)/vm/options.default $(OUTPUT_ROOT)/jdk/lib/
	cp -R $(OUTPUT_ROOT)/vm/java*properties $(OUTPUT_ROOT)/jdk/lib/
	mkdir -p $(OUTPUT_ROOT)/jdk/lib/j9vm
	cp $(OUTPUT_ROOT)/vm/redirector/libjvm_b156.so $(OUTPUT_ROOT)/jdk/lib/j9vm/libjvm.so
	cp $(OUTPUT_ROOT)/vm/j9vm_b156/libjvm.so $(OUTPUT_ROOT)/jdk/lib/compressedrefs
	cp $(OUTPUT_ROOT)/vm/classlib.properties  $(OUTPUT_ROOT)/jdk/lib
	cp $(OUTPUT_ROOT)/vm/classlib.properties $(OUTPUT_ROOT)/jdk/lib/compressedrefs

J9_LIST := java.base jdk.attach java.logging java.management
J9_SPECIFIC := com.ibm.management 
OPENJ9_IMAGE_DIR:=jdk

merge_module: compose-buildjvm
	$(eval $(shell rm -rf $(BUILD_JDK)/../moduleinfo.list))
	$(eval override MODULE_LIST = $(filter-out $(J9_SPECIFIC), $(filter-out $(J9_LIST),$(shell find $(BUILD_JDK)/modules/ -maxdepth 1 -type d -exec basename '{}' \; | tail -n +2 | tr '\n' ' '))))
	$(foreach module, $(J9_SPECIFIC), $(call copy-ibm-specific) $(\n))
	$(foreach module, $(J9_LIST), $(call merge-module-info) $(\n))
	$(foreach module, $(MODULE_LIST), $(call recompilation) $(\n))
	$(call compile-module-info)

compose:
	cp $(OPENJ9VM_SRC_DIR)/../tooling/jvmbuild_scripts/jvm.cfg $(IMAGES_OUTPUTDIR)/$(OPENJ9_IMAGE_DIR)/lib/
	$(SED) -i -e 's/shape=vm.shape/shape=b$(JDK_BUILD)/g' $(OUTPUT_ROOT)/vm/classlib.properties
	$(MKDIR) -p $(IMAGES_OUTPUTDIR)/$(OPENJ9_IMAGE_DIR)/lib/compressedrefs/
	cp -R $(OUTPUT_ROOT)/vm/*.so $(IMAGES_OUTPUTDIR)/$(OPENJ9_IMAGE_DIR)/lib/compressedrefs/
	cp $(OUTPUT_ROOT)/vm/J9TraceFormat.dat $(IMAGES_OUTPUTDIR)/$(OPENJ9_IMAGE_DIR)/lib/
	cp $(OUTPUT_ROOT)/vm/OMRTraceFormat.dat $(IMAGES_OUTPUTDIR)/$(OPENJ9_IMAGE_DIR)/lib/
	cp -R $(OUTPUT_ROOT)/vm/options.default $(IMAGES_OUTPUTDIR)/$(OPENJ9_IMAGE_DIR)/lib/
	cp -R $(OUTPUT_ROOT)/vm/java*properties $(IMAGES_OUTPUTDIR)/$(OPENJ9_IMAGE_DIR)/lib/
	mkdir -p $(IMAGES_OUTPUTDIR)/$(OPENJ9_IMAGE_DIR)/lib/j9vm
	cp $(OUTPUT_ROOT)/vm/redirector/libjvm_b156.so $(IMAGES_OUTPUTDIR)/$(OPENJ9_IMAGE_DIR)/lib/j9vm/libjvm.so
	cp $(OUTPUT_ROOT)/vm/j9vm_b156/libjvm.so $(IMAGES_OUTPUTDIR)/$(OPENJ9_IMAGE_DIR)/lib/compressedrefs
	cp $(OUTPUT_ROOT)/vm/classlib.properties  $(IMAGES_OUTPUTDIR)/$(OPENJ9_IMAGE_DIR)/lib
	cp $(OUTPUT_ROOT)/vm/classlib.properties $(IMAGES_OUTPUTDIR)/$(OPENJ9_IMAGE_DIR)/lib/compressedrefs

clean-j9:
	( cd $(OUTPUT_ROOT)/vm && \
		$(MAKE) clean )
clean-j9-dist:
	rm -fdr $(IMAGES_OUTPUTDIR)/$(OPENJ9_IMAGE_DIR)
	rm -fdr $(OUTPUT_ROOT)/vm

