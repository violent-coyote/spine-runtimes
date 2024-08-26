#!/bin/bash
set -e

dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
pushd "$dir" > /dev/null

if [ "$#" -lt 1 ]; then
	echo "Usage: ./build-templates.sh <platform> <mono:true|false>?"
	echo
	echo "e.g.:"
	echo "       ./build-templates.sh windows"
	echo "       ./build-templates.sh linux"
	echo "       ./build-templates.sh macos"
	echo "       ./build-templates.sh ios"
	echo "       ./build-templates.sh android"
	echo "       ./build-templates.sh web"
	echo
	exit 1
fi

if [ ! -d ../godot ]; then
	echo "No Godot clone found. Run ./setup.sh <Godot branch or tag> <dev> first."
	exit 1
fi

platform=${1%/}
mono=false

if [[ $# -eq 2 ]]; then
	mono=${2%/}
	if [ "$platform" != "windows" ] && [ "$platform" != "linux" ] && [ "$platform" != "macos" ]; then
		echo "C# is only supported for Windows, Linux, and macOS"
		exit 1
	fi
	echo "Building Godot template with C# support"
else
	echo "Building Godot template without C# support"
fi

mono_module=""
mono_extension=""
if [ $mono == "true" ]; then
	mono_module="module_mono_enabled=yes"
	mono_extension=".mono"
	echo "Building Godot with C# support"
else
	echo "Building Godot without C# support"
fi

cpus=2
if [ "$OSTYPE" = "msys" ]; then
	cpus=$NUMBER_OF_PROCESSORS
elif [[ "$OSTYPE" = "darwin"* ]]; then
	cpus=$(sysctl -n hw.logicalcpu)
else
	cpus=$(grep -c ^processor /proc/cpuinfo)
fi

# get the engine version from the metadata in source repo's version.py file
# 4.3 has nothreads as an option for web exports; 4.2 doesn't
major=$(grep "^major = " ../godot/version.py | cut -d= -f2 | tr -d ' ')
minor=$(grep "^minor = " ../godot/version.py | cut -d= -f2 | tr -d ' ')
patch=$(grep "^patch = " ../godot/version.py | cut -d= -f2 | tr -d ' ')
status=$(grep "^status = " ../godot/version.py | cut -d= -f2 | tr -d " '" | tr -d '"')

# Initialize version string with major
godot_version="$major"

# Add minor
godot_version="$version.$minor"

# Add patch if it's not zero
if [ "$patch" != "0" ]; then
    godot_version="$version.$patch"
fi

# Add status
godot_version="$version.$status"
echo "Godot version identified from ../godot/version.py as v${godot_version}"

pushd ../godot
if [ "$platform" = "windows" ]; then
	# --- Windows ---
	#generates windows_64_debug.exe and windows_64_release.exe
	scons platform=windows tools=no target=template_release custom_modules="../spine_godot" $mono_module --jobs=$cpus
	scons platform=windows tools=no target=template_debug custom_modules="../spine_godot" $mono_module --jobs=$cpus
	cp bin/godot.windows.template_release.x86_64$mono_extension.exe bin/windows_release_x86_64.exe
	cp bin/godot.windows.template_debug.x86_64$mono_extension.exe bin/windows_debug_x86_64.exe

elif [ "$platform" = "macos" ]; then
	# --- macOS ---
	# generates macos.zip

	scons platform=macos tools=no target=template_release arch=x86_64 custom_modules="../spine_godot" $mono_module --jobs=$cpus
	scons platform=macos tools=no target=template_debug arch=x86_64 custom_modules="../spine_godot" $mono_module --jobs=$cpus
	scons platform=macos tools=no target=template_release arch=arm64 custom_modules="../spine_godot" $mono_module --jobs=$cpus
	scons platform=macos tools=no target=template_debug arch=arm64 custom_modules="../spine_godot" $mono_module --jobs=$cpus
	lipo -create "bin/godot.macos.template_release.x86_64$mono_extension" "bin/godot.macos.template_release.arm64$mono_extension" -output bin/godot.macos.universal
	lipo -create "bin/godot.macos.template_debug.x86_64$mono_extension" "bin/godot.macos.template_debug.arm64$mono_extension" -output bin/godot.macos.debug.universal
	strip -S -x bin/godot.macos.universal

	pushd bin
	cp -r ../misc/dist/macos_template.app .
	mkdir -p macos_template.app/Contents/MacOS
	cp godot.macos.universal macos_template.app/Contents/MacOS/godot_macos_release.universal
	cp godot.macos.debug.universal macos_template.app/Contents/MacOS/godot_macos_debug.universal
	chmod +x macos_template.app/Contents/MacOS/godot_macos*
	rm -rf macos.zip
	zip -q -9 -r macos.zip macos_template.app
	popd
elif [ "$platform" = "linux" ]; then
	# --- Linux ---
	# generates linux_x11_64_release, linux_x11_64_debug
	scons platform=linuxbsd tools=no target=template_release bits=64 custom_modules="../spine_godot" $mono_module --jobs=$cpus
	scons platform=linuxbsd tools=no target=template_debug bits=64 custom_modules="../spine_godot" $mono_module --jobs=$cpus
	strip bin/godot.linuxbsd.template_release.x86_64$mono_extension
	strip bin/godot.linuxbsd.template_debug.x86_64$mono_extension
	chmod a+x bin/godot.linuxbsd.template_release.x86_64$mono_extension
	chmod a+x bin/godot.linuxbsd.template_debug.x86_64$mono_extension
	cp bin/godot.linuxbsd.template_release.x86_64$mono_extension bin/linux_release.x86_64
	cp bin/godot.linuxbsd.template_debug.x86_64$mono_extension bin/linux_debug.x86_64
elif [ "$platform" = "ios" ]; then
	# --- iOS --
	# generates ios.zip

	scons p=ios tools=no target=template_release arch=arm64 custom_modules="../spine_godot" --jobs=$cpus
	scons p=ios tools=no target=template_debug arch=arm64 custom_modules="../spine_godot" --jobs=$cpus
	scons p=ios tools=no target=template_release arch=arm64 ios_simulator=yes custom_modules="../spine_godot" --jobs=$cpus
	scons p=ios tools=no target=template_release arch=x86_64 ios_simulator=yes custom_modules="../spine_godot" --jobs=$cpus
	scons p=ios tools=no target=template_debug arch=arm64 ios_simulator=yes custom_modules="../spine_godot" --jobs=$cpus
	scons p=ios tools=no target=template_debug arch=x86_64 ios_simulator=yes custom_modules="../spine_godot" --jobs=$cpus
	lipo -create bin/libgodot.ios.template_release.arm64.simulator.a bin/libgodot.ios.template_release.x86_64.simulator.a -output bin/libgodot.ios.template_release.simulator.a
	lipo -create bin/libgodot.ios.template_debug.arm64.simulator.a bin/libgodot.ios.template_debug.x86_64.simulator.a -output bin/libgodot.ios.template_debug.simulator.a
	strip -S -x bin/libgodot.ios.template_release.arm64.a
	strip -S -x bin/libgodot.ios.template_release.simulator.a

	pushd bin
	cp -r ../misc/dist/ios_xcode .
	cp libgodot.ios.template_release.arm64.a ios_xcode/libgodot.ios.release.xcframework/ios-arm64/libgodot.a
	cp libgodot.ios.template_release.simulator.a ios_xcode/libgodot.ios.release.xcframework/ios-arm64_x86_64-simulator/libgodot.a
	cp libgodot.ios.template_debug.arm64.a ios_xcode/libgodot.ios.debug.xcframework/ios-arm64/libgodot.a
	cp libgodot.ios.template_debug.simulator.a ios_xcode/libgodot.ios.debug.xcframework/ios-arm64_x86_64-simulator/libgodot.a
	cp -r ~/VulkanSDK/1.3.250.1/MoltenVK/MoltenVK.xcframework ios_xcode/
  	rm -rf ios_xcode/MoltenVK.xcframework/{macos,tvos}*
	rm -rf ios.zip
	pushd ios_xcode
	zip -q -9 -r ../ios.zip *
	popd
	popd
elif [ "$platform" = "web" ]; then
	# --- WEB ---
	# https://github.com/godotengine/godot-docs/blob/b54f912c77304eb96093ba59dee8c3c69af0e8be/contributing/development/compiling/compiling_for_web.rst
	# generates all possible web export variants: 
	# web_debug.zip
	# web_dlink_debug.zip
	# web_dlink_nothreads_debug.zip
	# web_dlink_nothreads_release.zip
	# web_dlink_release.zip
	# web_nothreads_debug.zip
	# web_nothreads_release.zip
	# web_release.zip

	# `production=yes` is an alias for `use_static_cpp=yes debug_symbols=no lto=auto`
	# use `production=yes` with `debug_symbols=yes` to retain other optimizations but keep debug symbols
	# lto=full requires more RAM than comes with standard github actions runner; compilation will crash at the linking stage.
	# can also try lto=thin
	# recommended cloud runner flags: use_static_cpp=yes lto=thin

	# default (multithreaded)
	scons platform=web use_static_cpp=yes lto=thin tools=no target=template_release custom_modules="../spine_godot" --jobs=$cpus
	scons platform=web use_static_cpp=yes lto=thin debug_symbols=yes tools=no target=template_debug custom_modules="../spine_godot" --jobs=$cpus
	mv bin/godot.web.template_release.wasm32.zip bin/web_release.zip
	mv bin/godot.web.template_debug.wasm32.zip bin/web_debug.zip

	# dlink (GDExtension support)
	scons platform=web use_static_cpp=yes lto=thin dlink_enabled=yes tools=no target=template_release custom_modules="../spine_godot" --jobs=$cpus
	scons platform=web use_static_cpp=yes lto=thin debug_symbols=yes dlink_enabled=yes tools=no target=template_debug custom_modules="../spine_godot" --jobs=$cpus
	mv bin/godot.web.template_release.wasm32.dlink.zip bin/web_dlink_release.zip
	mv bin/godot.web.template_debug.wasm32.dlink.zip bin/web_dlink_debug.zip

	# Godot 4.3 and higher 
	if [ "$minor" -ge 3 ]; then
		# nothreads	(best firefox compatibility)
		scons platform=web use_static_cpp=yes lto=thin tools=no target=template_release threads=no custom_modules="../spine_godot" --jobs=$cpus
		scons platform=web use_static_cpp=yes lto=thin debug_symbols=yes tools=no target=template_debug threads=no custom_modules="../spine_godot" --jobs=$cpus
		mv bin/godot.web.template_release.wasm32.nothreads.zip bin/web_nothreads_release.zip
		mv bin/godot.web.template_debug.wasm32.nothreads.zip bin/web_nothreads_debug.zip

		# dlink nothreads
		scons platform=web use_static_cpp=yes lto=thin dlink_enabled=yes tools=no target=template_release threads=no custom_modules="../spine_godot" --jobs=$cpus
		scons platform=web use_static_cpp=yes lto=thin debug_symbols=yes dlink_enabled=yes tools=no target=template_debug threads=no custom_modules="../spine_godot" --jobs=$cpus
		mv bin/godot.web.template_release.wasm32.nothreads.dlink.zip bin/web_dlink_nothreads_release.zip
		mv bin/godot.web.template_debug.wasm32.nothreads.dlink.zip bin/web_dlink_nothreads_debug.zip
	fi

	# package the binaries in one archive (`tpz`), includes version.txt
	# (enables one-click in-editor web export install)
	# default version=4.3.stable, TODO: provide a version flag
	pushd bin
	echo $godot_version > version.txt

	zip "Godot_v${godot_version}_export_templates_web.tpz version.txt" \
	web_debug.zip \
	web_dlink_debug.zip \
	web_dlink_nothreads_debug.zip \
	web_dlink_nothreads_release.zip \
	web_dlink_release.zip \
	web_nothreads_debug.zip \
	web_nothreads_release.zip \
	web_release.zip
	popd

elif [ "$platform" = "android" ]; then
	# --- ANROID ---
	# generates android_release.apk, android_debug.apk, android_source.zip
	scons platform=android target=template_release android_arch=armv7 custom_modules="../spine_godot" --jobs=$cpus
	scons platform=android target=template_debug android_arch=armv7 custom_modules="../spine_godot" --jobs=$cpus
	scons platform=android target=template_release android_arch=arm64v8 custom_modules="../spine_godot" --jobs=$cpus
	scons platform=android target=template_debug android_arch=arm64v8 custom_modules="../spine_godot" --jobs=$cpus

	pushd platform/android/java
		chmod a+x gradlew
		./gradlew generateGodotTemplates
	popd
else
	echo "Unknown platform: $platform"
	exit 1
fi
popd
