ifneq ($(KERNELRELEASE),)
# kbuild part of makefile
ccflags-y += -g
include Kbuild
else
KDIR ?= /lib/modules/`uname -r`/build

default:
	$(MAKE) -C $(KDIR) M=$$PWD
	cp hello1.ko hello1.ko.unstripped
	cp hello2.ko hello2.ko.unstripped
	$(CROSS_COMPILE)strip -g hello1.ko
	$(CROSS_COMPILE)strip -g hello2.ko

clean:
	$(MAKE) -C $(KDIR) M=$$PWD clean
	rm -f *.ko.unstripped
endif

