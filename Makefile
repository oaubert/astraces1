SDKHOME:=$(if $(wildcard ../flex_sdk_4.5.1),../flex_sdk_4.5.1/bin/,$(error You must configure SDK path in Makefile))
APPNAME=Traces
SWC:=bin/$(APPNAME).swc
DEPFILES:=$(shell find src -name "*.as")
CLASSES:=$(shell find src -name "*.as" | sed 's/src\///; s/\.as//; s/\//./g')

all: $(SWC)

clean:
	-$(RM) $(SWC)

$(SWC): $(DEPFILES)
	"${SDKHOME}compc" -swf-version 11 -output "$@" -include-classes $(CLASSES) -source-path src
