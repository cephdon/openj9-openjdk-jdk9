# Locate make
MAKE := $(shell which make)
$(info MAKE = $(MAKE))

# Locate OpenJDK sources
OPENJDK_SRC_DIR := $(shell find . -maxdepth 1 -type d | grep jdk)
$(info OPENJDK_SRC_DIR = $(OPENJDK_SRC_DIR))
ifndef OPENJDK_SRC_DIR
	$(error Missing OpenJDK 9 sources! Run get_source.sh!)
endif

OPENJ9_SRC_DIR := $(shell find . -maxdepth 1 -type d | grep vm)
ifndef OPENJ9_SRC_DIR
	$(error Missing OpenJ9 VM sources! Run get_source.sh!)
endif

OPENJ9JCL_SRC_DIR := $(shell find . -maxdepth 1 -type d | grep j9jcl)
$(info OPENJ9JCL_SRC_DIR = $(OPENJ9JCL_SRC_DIR))
ifndef OPENJ9JCL_SRC_DIR
	$(error Missing OpenJ9 JCL sources! Run get_source.sh!)
endif

SPEC_FILE := $(shell find . -name spec.gmk)
$(info SPEC_FILE = $(SPEC_FILE))
ifdef SPEC_FILE
	include $(SPEC_FILE)
else
	$(error Missing OpenJDK SPEC file! Run configure first!)
endif


all: build-openjdk build-openj9
.PHONY: all

build-openjdk:
	( cd $(OPENJDK_SRC_DIR) && \
		$(MAKE) -f Makefile all )

-compile-openj9:
	@echo IMAGES_OUTPUTDIR = $(IMAGES_OUTPUTDIR)
	cp -R $(OPENJ9_SRC_DIR) $(OUTPUT_ROOT)/
	( cd $(OUTPUT_ROOT)/vm && \
		$(MAKE) -j 8 all )

-modify-jvm-cfg:
	@echo IMAGES_OUTPUTDIR = $(IMAGES_OUTPUTDIR)
	@$(SED) -i -e 's/server KNOWN/j9vm KNOWN/g' $(IMAGES_OUTPUTDIR)/sdk/lib/amd64/jvm.cfg
	@$(SED) -i -e 's/client IGNORE/hotspot IGNORE/g' $(IMAGES_OUTPUTDIR)/sdk/lib/amd64/jvm.cfg
	@echo '-classic IGNORE' >> $(IMAGES_OUTPUTDIR)/sdk/lib/amd64/jvm.cfg
	@echo '-native IGNORE' >> $(IMAGES_OUTPUTDIR)/sdk/lib/amd64/jvm.cfg
	@echo '-green IGNORE' >> $(IMAGES_OUTPUTDIR)/sdk/lib/amd64/jvm.cfg


openj9:
	@echo IMAGES_OUTPUTDIR = $(IMAGES_OUTPUTDIR)
	cp -R $(IMAGES_OUTPUTDIR)/jdk  $(IMAGES_OUTPUTDIR)/sdk
	# build precompuiled bootmodule and copy it to jdk/lib
	( cd $(IMAGES_OUTPUTDIR)/sdk/lib/modules && \
		../../bin/jimage extract bootmodules.jimage --dir bootmodules )
	( cd $(IMAGES_OUTPUTDIR)/sdk/lib/modules/bootmodules/java.base && \
		zip -q -r rt.jar . )
	mv $(IMAGES_OUTPUTDIR)/sdk/lib/modules/bootmodules/java.base/rt.jar $(IMAGES_OUTPUTDIR)/sdk/lib
	# modify vm/classlib.properties and copy it to jdk/lib
	@$(SED) -i -e 's/shape=sun/shape=b95/g' $(OUTPUT_ROOT)/vm/classlib.properties
	@$(SED) -i -e 's/version=1.7/version=1.9/g' $(OUTPUT_ROOT)/vm/classlib.properties
	cp $(OUTPUT_ROOT)/vm/classlib.properties  $(IMAGES_OUTPUTDIR)/sdk/lib
	# replace j9 libs
	cp -R $(OUTPUT_ROOT)/vm $(IMAGES_OUTPUTDIR)/sdk/lib/amd64/
	mv $(IMAGES_OUTPUTDIR)/sdk/lib/amd64/vm $(IMAGES_OUTPUTDIR)/sdk/lib/amd64/compressedrefs
	cp $(IMAGES_OUTPUTDIR)/sdk/lib/classlib.properties  $(IMAGES_OUTPUTDIR)/sdk/lib/amd64/compressedrefs
	mkdir -p $(IMAGES_OUTPUTDIR)/sdk/lib/amd64/j9vm
	cp $(IMAGES_OUTPUTDIR)/sdk/lib/amd64/compressedrefs/redirector/libjvm.so $(IMAGES_OUTPUTDIR)/sdk/lib/amd64/j9vm
	mkdir $(IMAGES_OUTPUTDIR)/sdk/lib/amd64/compressedrefs/jclSC190
	cp $(IMAGES_OUTPUTDIR)/jdk/lib/amd64/compressedrefs/J9_JCL/jclSC19B95/vm.jar $(IMAGES_OUTPUTDIR)/sdk/lib/amd64/compressedrefs/jclSC190/vm-b95.jar
	cp $(IMAGES_OUTPUTDIR)/sdk/lib/amd64/compressedrefs/J9TraceFormat.dat $(IMAGES_OUTPUTDIR)/sdk/lib
	cp $(IMAGES_OUTPUTDIR)/sdk/lib/amd64/compressedrefs/OMRTraceFormat.dat $(IMAGES_OUTPUTDIR)/sdk/lib
	cp $(OPENJ9JCL_SRC_DIR)/jcl-4-raw.jar $(IMAGES_OUTPUTDIR)/sdk/lib


build-openj9: -compile-openj9 openj9 -modify-jvm-cfg

.PHONY: clean 
clean: clean-openj9 clean-openjdk

clean-openj9:
	( cd $(OUTPUT_ROOT)/vm && \
		$(MAKE) clean )
	rm -fdr $(IMAGES_OUTPUTDIR)/jdk/lib/module/bootmodules

clean-openjdk:
	( cd $(OPENJDK_SRC_DIR) && \
		$(MAKE) -f Makefile clean )
