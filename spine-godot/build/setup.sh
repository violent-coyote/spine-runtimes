#!/bin/bash
set -e
godot_dir="godot"
dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
pushd "$dir" > /dev/null

if [ $# -lt 2 ] || [ $# -gt 4 ]; then
	echo "Usage: ./setup.sh <Godot branch or tag> <dev:true|false> <mono:true|false>? <godot-repository>?"
	echo
	echo "e.g.:"
	echo "       ./setup.sh 4.2.1-stable true"
	echo "       ./setup.sh master false true"
	echo "       ./setup.sh master false false https://github.com/my-github-username/godot.git"
	echo
	echo "Note: the 'mono' parameter only works for Godot 4.x+!"

	exit 1
fi

branch=${1%/}
dev=${2%/}
mono=false
repo=https://github.com/godotengine/godot.git

if [[ $# -eq 3 && "$branch" != 3* ]]; then
	mono=${3%/}
fi

if [ "$dev" != "true" ] && [ "$dev" != "false" ]; then
	echo "Invalid value for the 'dev' argument. It should be either 'true' or 'false'."
	exit 1
fi

if [ "$mono" != "true" ] && [ "$mono" != "false" ]; then
	echo "Invalid value for the 'mono' argument. It should be either 'true' or 'false'."
	exit 1
fi

if [ $# -eq 4 ]; then
    repo=${4%/}
fi

pushd ..
rm -rf $godot_dir
git clone --depth 1 $repo -b $branch $godot_dir
if [ $dev = "true" ]; then
	cp -r .idea $godot_dir
	cp build/custom.py $godot_dir
	if [ "$mono" = "true" ]; then
		echo "" >> $godot_dir/custom.py
    	echo "module_mono_enabled=\"yes\"" >> $godot_dir/custom.py
	fi
	cp ../formatters/.clang-format .
	rm -rf example/.import
	rm -rf example/.godot

	#if [ "$OSTYPE" = "msys" ]; then
	#	pushd godot
	#	if [[ $branch == 3* ]]; then
	#		echo "Applying V3 Live++ patch"
	#		git apply ../build/livepp.patch
	#	else
	#		echo "Applying V4 Live++ patch"
	#		git apply ../build/livepp-v4.patch
	#	fi
	#	popd
	#fi

	if [ `uname` == 'Darwin' ] && [ ! -d "$HOME/VulkanSDK" ]; then
		./build/install-macos-vulkan-sdk.sh
	fi
fi
cp -r ../spine-cpp/spine-cpp spine_godot
popd

popd > /dev/null
