SDKHOME:=$(if $(wildcard ../flex_sdk_4.5.1),../flex_sdk_4.5.1,$(error You must configure SDK path in Makefile))
SDKBIN:=${SDKHOME}/bin/
SDKFRAMEWORK:=${SDKHOME}/frameworks/libs

APPNAME=Traces
SWC:=bin/$(APPNAME).swc
DEPFILES:=$(shell find src -name "*.as")
CLASSES:=$(shell find src -name "*.as" | sed 's/src\///; s/\.as//; s/\//./g')

all: $(SWC)

swc: $(SWC)

clean:
	-$(RM) $(SWC)

$(SWC): $(DEPFILES)
	"${SDKBIN}compc" -swf-version 11 -debug=true -as3 -external-library-path+=$(SDKFRAMEWORK)/framework.swc -output "$@" -include-classes $(CLASSES) -source-path src
