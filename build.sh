#!/bin/bash
set -e

# define compilation targets
declare -A PLATFORMS
PLATFORMS[android_386_cgo]=x86
PLATFORMS[android_amd64_cgo]=x86_64
PLATFORMS[android_arm_cgo]=armeabi-v7a
PLATFORMS[android_arm64_cgo]=arm64-v8a

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

# the dispatcher socket path is hardcoded; instead, we want to read it from an environment variable
[ ! -f go/lib/sock/reliable/reliable.go.orig2 ] && (
	sed -E -i.orig2 's/import.*\(/import ("os"/' go/lib/sock/reliable/reliable.go && # add the "os" package
	sed -E -i.orig3 's/DefaultDispPath.*=.*//' go/lib/sock/reliable/reliable.go && # remove the hardcoded dispatcher socket path
	# re-add the path as environment variable
	echo >> go/lib/sock/reliable/reliable.go &&
	echo 'func getEnv(key, fallback string) string { if value, ok := os.LookupEnv(key); ok { return value }; return fallback }' >> go/lib/sock/reliable/reliable.go &&
	echo 'var ( DefaultDispPath = getEnv("DISPATCHER_SOCKET", "/run/shm/dispatcher/default.sock") )' >> go/lib/sock/reliable/reliable.go)

# register Android NDK with Bazel
grep -qF 'android_ndk_repository' WORKSPACE || (echo >> WORKSPACE &&
	echo 'android_ndk_repository(name = "androidndk", path = "/home/vagrant/android-ndk")' >> WORKSPACE &&
	echo 'register_toolchains("@androidndk//:all")' >> WORKSPACE)

# build SCION (Intel/AMD and ARM 32-bit and 64-bit for Android and a debug build for amd64 as well)
rm -rf /vagrant/jniLibs
rm -f bazel-bin/go/scion-android/*/scion-android
yes | ./env/deps
make -C go/proto
bazel build //go/scion-android # debug build
cp bazel-bin/go/scion-android/linux_amd64_stripped_pie/scion-android /vagrant/test/libscion-android.so
for platform in "${!PLATFORMS[@]}"; do
	# build with Bazel, use C crosscompiler provided by Android NDK
	bazel build //go/scion-android \
		--crosstool_top=@androidndk//:default_crosstool --host_crosstool_top=@bazel_tools//tools/cpp:toolchain --cpu="${PLATFORMS[$platform]}" \
		--platforms=@io_bazel_rules_go//go/toolchain:$platform

	# copy executable to destination, suitable to be imported in Android Studio
	export TARGET_DIR=/vagrant/jniLibs/${PLATFORMS[$platform]}
	mkdir -p $TARGET_DIR
	cp bazel-bin/go/scion-android/*/scion-android $TARGET_DIR/libscion-android.so
	rm -f bazel-bin/go/scion-android/*/scion-android
done
popd
