CC        = clang
CXX       = clang++
CSTANDARD = -std=c++17

HOSTARCH        = a12
POSTFIX         = BETA
VERSION         = 0.8
VERSIONMRUBY    = 3.4.0
VERSIONLUA	    = 5.4.8

EXECUTABLE    = WinterMoon
APPNAME       = Winter__Moon__Testing
APPICON       = AppIcon
ROOTDIRECTORY = ../

all:     retail postclean preclean inject plist macapp librari luascripts macos                bin          distribution
test:    debugf postclean preclean inject plist macapp librari luascripts macos    macos-debug bin savefile              launch
messy:   debugf           preclean inject plist macapp librari luascripts macos    macos-debug bin savefile distribution
sanity:  debugf postclean preclean inject plist macapp librari luascripts macos    macos-debug bin
ppcmake: ppcflg postclean preclean inject plist macapp librari luascripts macosppc             bin


intel64:
	@echo setting ia64 flags...
	$(eval HOSTARCH = x64)
intel32:
	@echo setting ia32 flags...
	$(eval HOSTARCH = x86)
powerpc32:
	@echo setting ppc flags...
	$(eval HOSTARCH = ppc)
powerpc64:
	@echo setting ppc64 flags...
	$(eval HOSTARCH = ppc64)
arm32:
	@echo setting arm7 flags...
	$(eval HOSTARCH = a9)
arm64:
	@echo setting arm8 flags...
	$(eval HOSTARCH = a12)

retail:
	@echo setting retail flags...
	$(eval UFLAGS = -O3 -funroll-loops -flto -g0)
	$(eval LUAFLAGS = -s -o)

ppcflg:
	@echo setting ppc build flags...
	$(eval UFLAGS = -O3 -funroll-loops -pg -g0)
	$(eval LUAFLAGS = -s -o)
	$(eval HOSTARCH = ppc)
	$(eval CC = /opt/local/bin/gcc-mp-14)
	$(eval CXX = /opt/local/bin/g++-mp-14)
	$(eval CSTANDARD = -std=c++17)

debugf:
	@echo setting debug flags...
	$(eval UFLAGS = -O0)
	$(eval LUAFLAGS = -o)

preclean:
	find . -name "._*" -delete
	rm -rf build/*
	rm -rf $(EXECUTABLE).app
	rm -rf $(EXECUTABLE)\ 2.app
	rm -rf $(EXECUTABLE).dmg
	rm -rf $(EXECUTABLE)
	rm -rf $(EXECUTABLE)-a12
	rm -rf $(EXECUTABLE)-x64
	rm -rf $(EXECUTABLE)-ppc
	rm -f main.cpp
	rm -f main.mm
	rm -f index
	rm -f luac.out
	rm -f Info.plist
	rm -f out.lua
	rm -f lua-bytecode.h
	rm -f luac.error
	rm -f error-bytecode.h
	rm -f quartz_window.o

inject:
	@echo running injections...
	./libraries/$(HOSTARCH)/lua injector.lua $(VERSION) $(ROOTDIRECTORY) $(APPNAME) lua.lua out.lua $(POSTFIX)
	./libraries/$(HOSTARCH)/lua injector.lua $(VERSION) $(ROOTDIRECTORY) $(APPNAME) index.cpp main.cpp $(POSTFIX)
	./libraries/$(HOSTARCH)/luac $(LUAFLAGS) luac.out out.lua
	xxd -i luac.out > lua-bytecode.h

plist:
	@echo building macos bundle info...
	./libraries/$(HOSTARCH)/lua macapp.lua $(EXECUTABLE) $(APPNAME) $(VERSION) $(APPICON)

macapp:
	@echo building macos app structure...
	mkdir $(EXECUTABLE).app
	mkdir $(EXECUTABLE).app/Contents
	mkdir $(EXECUTABLE).app/Contents/Resources
	mkdir $(EXECUTABLE).app/Contents/Resources/volatile
	mkdir $(EXECUTABLE).app/Contents/MacOS
	@echo copying files...
	cp vars.txt $(EXECUTABLE).app/Contents/Resources/vars.txt
	cp docs.txt $(EXECUTABLE).app/Contents/Resources/docs.txt
	cp targets.txt $(EXECUTABLE).app/Contents/Resources/targets.txt
	mv Info.plist $(EXECUTABLE).app/Contents/Info.plist
	cp -R package $(EXECUTABLE).app/Contents/Resources/
	cp -R ast/scripts $(EXECUTABLE).app/Contents/Resources/
	mv $(EXECUTABLE).app/Contents/Resources/package/$(APPICON).png $(EXECUTABLE).app/Contents/Resources/$(APPICON).png
	cp save-1.plush $(EXECUTABLE).app/Contents/Resources/volatile/save-1.plush

luascripts:
	./libraries/$(HOSTARCH)/lua injector.lua $(VERSION) $(ROOTDIRECTORY) $(APPNAME) $(EXECUTABLE).app/Contents/Resources/scripts/abyss.lua $(EXECUTABLE).app/Contents/Resources/scripts/abyss.lua $(POSTFIX)
	./libraries/$(HOSTARCH)/lua injector.lua $(VERSION) $(ROOTDIRECTORY) $(APPNAME) $(EXECUTABLE).app/Contents/Resources/scripts/quartz-test.lua $(EXECUTABLE).app/Contents/Resources/scripts/quartz-test.lua $(POSTFIX)
	./libraries/$(HOSTARCH)/lua injector.lua $(VERSION) $(ROOTDIRECTORY) $(APPNAME) $(EXECUTABLE).app/Contents/Resources/scripts/raycast.lua $(EXECUTABLE).app/Contents/Resources/scripts/raycast.lua $(POSTFIX)
	./libraries/$(HOSTARCH)/lua injector.lua $(VERSION) $(ROOTDIRECTORY) $(APPNAME) $(EXECUTABLE).app/Contents/Resources/scripts/visual-novel.lua $(EXECUTABLE).app/Contents/Resources/scripts/visual-novel.lua $(POSTFIX)
	./libraries/$(HOSTARCH)/lua injector.lua $(VERSION) $(ROOTDIRECTORY) $(APPNAME) $(EXECUTABLE).app/Contents/Resources/scripts/projection.lua $(EXECUTABLE).app/Contents/Resources/scripts/projection.lua $(POSTFIX)

extern:
	@echo copying external binaries...
	cp -R ast/binaries $(EXECUTABLE).app/Contents

librari:
	@echo injecting libraries...
	mkdir $(EXECUTABLE).app/Contents/Libraries
	cp libraries/anglish $(EXECUTABLE).app/Contents/Libraries/anglish
	cp libraries/gender $(EXECUTABLE).app/Contents/Libraries/gender

macos:
	@echo building $(EXECUTABLE)...
	$(CXX) $(CSTANDARD) $(UFLAGS) \
	-mmacosx-version-min=11.00 -mcpu=apple-a12 -fobjc-arc \
	main.cpp metal_window.mm metal_mixer.mm ScriptEngine.cpp \
	-o $(EXECUTABLE)-a12 \
	-DUSE_MACOS_PLATFORM -DUSE_MACOS_WINDOW -DUSE_MACOS_PNG -DUSE_MACOS_MIXER -DUSE_MACOS_FONT -DUSE_LIB_RUBY -DUSE_WINTERSCRIPT -DUSE_MODERN_MACOS \
	-I./include/lua/$(VERSIONLUA)/ -I./include/mruby/$(VERSIONMRUBY)/ \
	-L./libraries/a12 -llua -lm -lmruby \
	-framework CoreText -framework CoreGraphics -framework ImageIO -framework Cocoa \
	-framework AudioToolbox -framework CoreFoundation -framework AVFoundation -framework Foundation \
	-framework Metal -framework MetalKit -framework Carbon
	$(CXX) $(CSTANDARD) $(UFLAGS) \
	-mmacosx-version-min=11.00 -target x86_64-apple-macos11 -fobjc-arc \
	main.cpp metal_window.mm metal_mixer.mm ScriptEngine.cpp \
	-o $(EXECUTABLE)-x64 \
	-DUSE_MACOS_PLATFORM -DUSE_MACOS_WINDOW -DUSE_MACOS_PNG -DUSE_MACOS_MIXER -DUSE_MACOS_FONT -DUSE_LIB_RUBY -DUSE_WINTERSCRIPT -DUSE_MODERN_MACOS \
	-I./include/lua/$(VERSIONLUA)/ -I./include/mruby/$(VERSIONMRUBY)/ \
	-L./libraries/x64 -llua -lm -lmruby \
	-framework CoreText -framework CoreGraphics -framework ImageIO -framework Cocoa \
	-framework AudioToolbox -framework CoreFoundation -framework AVFoundation -framework Foundation \
	-framework Metal -framework MetalKit -framework Carbon
	lipo -create -output $(EXECUTABLE) $(EXECUTABLE)-a12 $(EXECUTABLE)-x64

macosppc:
	@echo building $(EXECUTABLE)...
	$(CXX) $(CSTANDARD) $(UFLAGS) \
	-Wno-multichar -Wno-deprecated -Wno-subobject-linkage -Wno-endif-labels -Wno-deprecated-declarations \
	-mmacosx-version-min=10.5 -mcpu=G4 -mtune=G4 -x objective-c++ \
	main.cpp quartz_window.mm \
	-o $(EXECUTABLE)-ppc \
	-DUSE_MACOS_PLATFORM -DUSE_QUARTZ_WINDOW -DUSE_MACOS_PNG -DUSE_QUARTZ_AUDIO -DUSE_QUARTZ_FONT -DUSE_LIB_RUBY -DUSE_LEGACY_MACOS \
	-I./include/lua/$(VERSIONLUA)/ -F/Developer/SDKs/MacOSX10.5.sdk/System/Library/Frameworks \
	-I/Developer/SDKs/MacOSX10.5.sdk/System/Library/Frameworks/CoreGraphics.framework/Headers \
	-I/Developer/SDKs/MacOSX10.5.sdk/System/Library/Frameworks/ApplicationServices.framework/Frameworks/ImageIO.framework/Headers \
	-I/Developer/SDKs/MacOSX10.5.sdk/System/Library/Frameworks/ApplicationServices.framework/Headers \
	-I/Developer/SDKs/MacOSX10.5.sdk/System/Library/Frameworks/CoreServices.framework/Headers \
	-I/Developer/SDKs/MacOSX10.5.sdk/System/Library/Frameworks/Quartz.framework/Headers \
	-F/Developer/SDKs/MacOSX10.5.sdk/System/Library/Frameworks \
	-L./libraries/ppc -llua -lm -lmruby \
	-framework CoreFoundation -framework Cocoa \
	-framework AudioToolbox -framework AudioUnit \
	-framework Quartz -framework Carbon -framework ApplicationServices
	cp $(EXECUTABLE)-ppc $(EXECUTABLE)

generic:
	@echo building $(EXECUTABLE)...
	mkdir lodepng
	cp include/lodepng.cpp lodepng/lodepng.cpp
	cp include/lodepng.h lodepng/lodepng.h
	$(CXX) $(CSTANDARD) $(UFLAGS) \
	main.cpp lodepng/lodepng.cpp \
	-o $(EXECUTABLE)-generic \
	-DUSE_LODE_PNG -DUSE_TINY_AUDIO -DUSE_TTF_FONT -DUSE_LIB_RUBY \
	-I./include/lua/$(VERSIONLUA)/ -I./include/mruby/$(VERSIONMRUBY)/ \
	-L./libraries/unix -llua -lm -lmruby

macos-debug:
	@echo copying extra binaries...
	mv $(EXECUTABLE)-a12 $(EXECUTABLE).app/Contents/MacOS/$(EXECUTABLE)-a12
	mv $(EXECUTABLE)-x64 $(EXECUTABLE).app/Contents/MacOS/$(EXECUTABLE)-x64

bin:
	@echo moving binary...
	mv $(EXECUTABLE) $(EXECUTABLE).app/Contents/MacOS/$(EXECUTABLE)

launch:
	./$(EXECUTABLE).app/Contents/MacOS/$(EXECUTABLE)

savefile:
	@echo copying debug savefiles...
	cp save0.plush $(EXECUTABLE).app/Contents/Resources/volatile/save0.plush
	cp save1.plush $(EXECUTABLE).app/Contents/Resources/volatile/save1.plush

distribution:
	@echo creating distribution package...
	codesign --remove-signature "$(EXECUTABLE).app"
	xattr -cr "$(EXECUTABLE).app"
	codesign -s - -f -v --timestamp --options=runtime --deep "$(EXECUTABLE).app"
	hdiutil create -fs HFS+ -volname "$(EXECUTABLE) v$(VERSION) $(POSTFIX)" -srcfolder "$(EXECUTABLE).app" -ov -format UDCO "$(EXECUTABLE).dmg"

postclean:
	@echo cleaning up...
	find . -type f \( -name "*.o" -o -name "*\.o" \) -delete
	rm -rf lodepng