#!/bin/bash
set -e

# define compilation targets
declare -A PLATFORMS
PLATFORMS[linux_386]=x86
PLATFORMS[linux_amd64]=x86_64
PLATFORMS[linux_arm]=armeabi-v7a
PLATFORMS[linux_arm64]=arm64-v8a

# define compilation units
export MAIN_FILES="beacon_srv/main.go border/main.go cert_srv/main.go godispatcher/main.go tools/logdog/main.go path_srv/main.go tools/scion-custpk-load/main.go sciond/main.go tools/scion-pki/main.go tools/scmp/main.go tools/showpaths/paths.go sig/main.go"
export BAZEL_FILES="beacon_srv/BUILD.bazel border/BUILD.bazel cert_srv/BUILD.bazel godispatcher/BUILD.bazel tools/logdog/BUILD.bazel path_srv/BUILD.bazel tools/scion-custpk-load/BUILD.bazel sciond/BUILD.bazel tools/scion-pki/BUILD.bazel tools/scmp/BUILD.bazel tools/showpaths/BUILD.bazel sig/BUILD.bazel"

pushd "$GOPATH/src/github.com/scionproto/scion"

# add code for creating a single SCION executable (to allow sharing RAM, and to compensate for missing dynamic linking)
cp -R /vagrant/scion-android go

# export main function as AndroidMain in all binaries
for f in $MAIN_FILES; do
    grep -qxF 'func AndroidMain() { main() }' go/$f || echo 'func AndroidMain() { main() }' >> go/$f
done

# make every binary's library public so they can be used as dependencies
for f in $BAZEL_FILES; do
    sed -E -i.orig 's_"//visibility:private"_"//visibility:public"_' go/$f
done

# prepend binary name to every flag definition to avoid collisions
for f in `find go -name '*.go'`; do
    [ ! -f $f.orig ] && sed -E -i.orig 's/(flag\.[^"]+")([^"]*)"/\1'$(echo $(dirname $f) | tr '/' '_' | sed -e 's/go_//')'_\2"/' $f
done

# build SCION for Android (Intel/AMD and ARM 32-bit and 64-bit)
rm -rf /vagrant/bin
rm -f bazel-bin/go/scion-android/*/scion-android
yes | ./env/deps
make -C go/proto
for platform in "${!PLATFORMS[@]}"; do
	bazel build --platforms=@io_bazel_rules_go//go/toolchain:$platform //go/scion-android --workspace_status_command=./tools/bazel-build-env
done

# copy SCION executables to destination
export VERSION=$(bazel-bin/go/scion-android/linux_amd64*/scion-android godispatcher -lib_env_version | cut -d: -f2 | cut -d- -f1 | xargs)
for dir in `ls bazel-bin/go/scion-android`; do
	export ARCH=$(echo $dir | cut -d_ -f1-2)
	export TARGET_DIR=/vagrant/bin/$VERSION/${PLATFORMS[$ARCH]}
	mkdir -p $TARGET_DIR
	cp bazel-bin/go/scion-android/$dir/scion-android $TARGET_DIR/libscion-android.so
done
popd
