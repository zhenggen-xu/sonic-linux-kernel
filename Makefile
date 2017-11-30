.ONESHELL:
SHELL = /bin/bash
.SHELLFLAGS += -e

KVERSION_SHORT ?= 4.9.0-3
KVERSION ?= $(KVERSION_SHORT)-amd64
KERNEL_VERSION ?= 4.9.30
KERNEL_SUBVERSION ?= 2+deb9u5

MAIN_TARGET = linux-headers-$(KVERSION_SHORT)-common_$(KERNEL_VERSION)-$(KERNEL_SUBVERSION)_all.deb
DERIVED_TARGETS = linux-headers-$(KVERSION)_$(KERNEL_VERSION)-$(KERNEL_SUBVERSION)_amd64.deb \
                 linux-image-$(KVERSION)_$(KERNEL_VERSION)-$(KERNEL_SUBVERSION)_amd64.deb

DSC_FILE = linux_$(KERNEL_VERSION)-$(KERNEL_SUBVERSION).dsc
ORIG_FILE = linux_$(KERNEL_VERSION).orig.tar.xz
DEBIAN_FILE = linux_$(KERNEL_VERSION)-$(KERNEL_SUBVERSION).debian.tar.xz
URL = http://security.debian.org/debian-security/pool/updates/main/l/linux
BUILD_DIR=linux-$(KERNEL_VERSION)

DSC_FILE_URL = "$(URL)/$(DSC_FILE)"
DEBIAN_FILE_URL = "$(URL)/$(DEBIAN_FILE)"
ORIG_FILE_URL = "$(URL)/$(ORIG_FILE)"

$(addprefix $(DEST)/, $(MAIN_TARGET)): $(DEST)/% :
	# Obtaining the Debian kernel source
	rm -rf $(BUILD_DIR)
	wget -O $(DSC_FILE) $(DSC_FILE_URL)
	wget -O $(ORIG_FILE) $(ORIG_FILE_URL)
	wget -O $(DEBIAN_FILE) $(DEBIAN_FILE_URL)

	dpkg-source -x $(DSC_FILE)

	pushd $(BUILD_DIR)
	git init
	git add -f *

	# patch debian changelog and update kernel package version
	# git am ../patch/changelog.patch

	# re-generate debian/rules.gen, requires kernel-wedge
	# debian/bin/gencontrol.py

	# generate linux build file for amd64_none_amd64
	fakeroot make -f debian/rules.gen setup_amd64_none_amd64

	# Applying patches and configuration changes
	git add debian/build/build_amd64_none_amd64/.config -f
	git commit -m "unmodified debian source"
	stg init
	stg import -s ../patch/series

	# Building a custom kernel from Debian kernel source
	DO_DOCS=False fakeroot make -f debian/rules -j $(shell nproc) binary-indep
	fakeroot make -f debian/rules.gen -j $(shell nproc) binary-arch_amd64_none
	popd

ifneq ($(DEST),)
	mv $(DERIVED_TARGETS) $* $(DEST)/
endif

$(addprefix $(DEST)/, $(DERIVED_TARGETS)): $(DEST)/% : $(DEST)/$(MAIN_TARGET)
