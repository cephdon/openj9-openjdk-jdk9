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

NUMCPU := $(shell grep -c ^processor /proc/cpuinfo)
#$(info NUMCPU = $(NUMCPU))

override MAKEFLAGS := -j $(NUMCPU)

.PHONY: clean-j9 clean-j9-dist compile-j9 stage-j9 run-preprocessors-j9 build-j9 compose compose-buildjvm generate-j9jcl-sources
.NOTPARALLEL:
build-j9: stage-j9 run-preprocessors-j9 compile-j9 

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
	cp $(OPENJ9BINARIES_DIR)/common/third/xercesImpl.jar $(OUTPUT_ROOT)/vm/sourcetools/lib/
	cp $(OPENJ9BINARIES_DIR)/common/third/dom4j-1.6.1.jar $(OUTPUT_ROOT)/vm/sourcetools/lib/
	cp $(OPENJ9BINARIES_DIR)/common/third/xmlParserAPIs-2.0.2.jar $(OUTPUT_ROOT)/vm/sourcetools/lib/
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
	(export BOOT_JDK=$(BOOT_JDK) && cd $(OUTPUT_ROOT)/vm && $(MAKE) $(MAKEFLAGS) -f buildtools.mk SPEC=$(J9_PLATFORM) JAVA_HOME=$(BOOT_JDK) BUILD_ID=000000 UMA_OPTIONS_EXTRA="-buildDate $(shell date +'%Y%m%d')" tools)
	$(eval J9VM_SHA=$(shell git -C $(OPENJ9VM_SRC_DIR) rev-parse --short HEAD))
	@sed -i -e 's/developer.compile/$(J9VM_SHA)/g' $(OUTPUT_ROOT)/vm/include/j9version.h
	@echo J9VM version string set to : $(J9VM_SHA)
	sed -i -e 's/gcc-4.6/gcc/g' $(OUTPUT_ROOT)/vm/makelib/mkconstants.mk
	sed -i -e 's/O3 -fno-strict-aliasing/O0 -Wno-format -Wno-unused-result -fno-strict-aliasing -fno-stack-protector/g' $(OUTPUT_ROOT)/vm/makelib/targets.mk
	@echo "---------------- Finished OpenJ9 preprocessors ------------------------"

compile-j9: run-preprocessors-j9 
	@echo "----------------Compiling OpenJ9 in $(OUTPUT_ROOT)/vm ------------------"
	(cd $(OUTPUT_ROOT)/vm && $(MAKE) $(MAKEFLAGS) all)
	mkdir -p $(OUTPUT_ROOT)/support/modules_libs/java.base/server/
	cp $(OUTPUT_ROOT)/vm/j9vm_b156/libjvm.so $(OUTPUT_ROOT)/support/modules_libs/java.base/server/
	cp $(OUTPUT_ROOT)/vm/libjsig.so $(OUTPUT_ROOT)/support/modules_libs/java.base/
	@echo "--------------------- Finished compiling OpenJ9 ------------------------"

generate-j9jcl-sources:
	$(BOOT_JDK)/bin/java -cp "$(OPENJ9BINARIES_DIR)/vm/ibm/*:$(OPENJ9BINARIES_DIR)/common/third/*" com.ibm.jpp.commandline.CommandlineBuilder -verdict -baseDir "" -config "SIDECAR19-SE" -srcRoot "$(OPENJ9VM_SRC_DIR)/jcl" -xml "$(OPENJ9VM_SRC_DIR)/jcl/jpp_configuration.xml" -dest "$(SUPPORT_OUTPUTDIR)/j9jcl_sources" -macro:define "com.ibm.oti.vm.library.version=29;com.ibm.oti.jcl.build=326747" -tag:define "Stream2.5;Stream2.6;" -tag:remove "null;"
	find $(SUPPORT_OUTPUTDIR)/j9jcl_sources -name module-info.java -exec mv {} {}.extra \;
	mkdir -p $(SUPPORT_OUTPUTDIR)/gensrc/java.base/
	cp -rp $(SUPPORT_OUTPUTDIR)/j9jcl_sources/java.base/* $(SUPPORT_OUTPUTDIR)/gensrc/java.base/

compose-buildjvm:
	cp $(OPENJ9VM_SRC_DIR)/../tooling/jvmbuild_scripts/jvm.cfg $(OUTPUT_ROOT)/jdk/lib/
	$(SED) -i -e 's/shape=vm.shape/shape=b$(JDK_BUILD)/g' $(OUTPUT_ROOT)/vm/classlib.properties
	$(MKDIR) -p $(OUTPUT_ROOT)/jdk/lib/compressedrefs/
	cp -R $(OUTPUT_ROOT)/vm/*.so $(JDK_OUTPUTDIR)/lib/compressedrefs/
	cp $(OUTPUT_ROOT)/vm/J9TraceFormat.dat $(JDK_OUTPUTDIR)/lib/
	cp $(OUTPUT_ROOT)/vm/OMRTraceFormat.dat $(JDK_OUTPUTDIR)/lib/
	cp -R $(OUTPUT_ROOT)/vm/options.default $(JDK_OUTPUTDIR)/lib/
	cp -R $(OUTPUT_ROOT)/vm/java*properties $(JDK_OUTPUTDIR)/lib/
	mkdir -p $(JDK_OUTPUTDIR)/lib/j9vm
	cp $(OUTPUT_ROOT)/vm/redirector/libjvm_b156.so $(JDK_OUTPUTDIR)/lib/j9vm/libjvm.so
	cp $(OUTPUT_ROOT)/vm/j9vm_b156/libjvm.so $(JDK_OUTPUTDIR)/lib/compressedrefs
	cp $(OUTPUT_ROOT)/vm/classlib.properties  $(JDK_OUTPUTDIR)/lib

compose:
	cp $(OPENJ9VM_SRC_DIR)/../tooling/jvmbuild_scripts/jvm.cfg $(IMAGES_OUTPUTDIR)/jdk/lib/
	$(SED) -i -e 's/shape=vm.shape/shape=b$(JDK_BUILD)/g' $(OUTPUT_ROOT)/vm/classlib.properties
	$(MKDIR) -p $(IMAGES_OUTPUTDIR)/jdk/lib/compressedrefs/
	cp -R $(OUTPUT_ROOT)/vm/*.so $(IMAGES_OUTPUTDIR)/jdk/lib/compressedrefs/
	cp $(OUTPUT_ROOT)/vm/J9TraceFormat.dat $(IMAGES_OUTPUTDIR)/jdk/lib/
	cp $(OUTPUT_ROOT)/vm/OMRTraceFormat.dat $(IMAGES_OUTPUTDIR)/jdk/lib/
	cp -R $(OUTPUT_ROOT)/vm/options.default $(IMAGES_OUTPUTDIR)/jdk/lib/
	cp -R $(OUTPUT_ROOT)/vm/java*properties $(IMAGES_OUTPUTDIR)/jdk/lib/
	mkdir -p $(IMAGES_OUTPUTDIR)/jdk/lib/j9vm
	cp $(OUTPUT_ROOT)/vm/redirector/libjvm_b156.so $(IMAGES_OUTPUTDIR)/jdk/lib/j9vm/libjvm.so
	cp $(OUTPUT_ROOT)/vm/j9vm_b156/libjvm.so $(IMAGES_OUTPUTDIR)/jdk/lib/compressedrefs
	cp $(OUTPUT_ROOT)/vm/classlib.properties  $(IMAGES_OUTPUTDIR)/jdk/lib

clean-j9:
	( cd $(OUTPUT_ROOT)/vm && \
		$(MAKE) clean )
clean-j9-dist:
	rm -fdr $(OUTPUT_ROOT)/vm

