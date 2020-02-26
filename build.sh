#!/bin/bash
set -e

export RULES_GO_VERSION=v0.21.3
export GAZELLE_URL="https://github.com/bazelbuild/bazel-gazelle/releases/download/v0.20.0/bazel-gazelle-v0.20.0.tar.gz"
export GAZELLE_SHA256="d8c45ee70ec39a57e7a05e5027c32b1576cc7f16d9dd37135b0eddde45cf1b10"

declare -A PLATFORMS
PLATFORMS[android_386_cgo]=x86
PLATFORMS[android_amd64_cgo]=x86_64
PLATFORMS[android_arm_cgo]=armeabi-v7a
PLATFORMS[android_arm64_cgo]=arm64-v8a

if [ -z "$SCION_NAME" ]; then
	echo "No name of SCION executable given."
	exit 1
fi

if [ ! -z "$SCION_REPOSITORY" ] && [ ! -z "$SCION_COMMIT" ]; then
	echo "Cloning SCION repository $SCION_REPOSITORY ..."
	cd /vagrant
	rm -rf /vagrant/scion
	git clone -q $SCION_REPOSITORY
	cd scion
	echo "Checking out $SCION_COMMIT ..."
	git checkout -q $SCION_COMMIT
	echo "Linking repository into Go workspace ..."
	mkdir -p "$GOPATH/src/github.com/scionproto"
	cd "$GOPATH/src/github.com/scionproto"
	ln -s /vagrant/scion scion
fi

# define compilation units
export MAIN_FILES="beacon_srv/main.go border/main.go cert_srv/main.go godispatcher/main.go tools/logdog/main.go path_srv/main.go tools/scion-custpk-load/main.go sciond/main.go tools/scion-pki/main.go tools/scmp/main.go tools/showpaths/paths.go sig/main.go"
export BAZEL_FILES="beacon_srv/BUILD.bazel border/BUILD.bazel cert_srv/BUILD.bazel godispatcher/BUILD.bazel tools/logdog/BUILD.bazel path_srv/BUILD.bazel tools/scion-custpk-load/BUILD.bazel sciond/BUILD.bazel tools/scion-pki/BUILD.bazel tools/scmp/BUILD.bazel tools/showpaths/BUILD.bazel sig/BUILD.bazel"

pushd "$GOPATH/src/github.com/scionproto/scion" > /dev/null

# add code for creating a single SCION executable (to allow sharing RAM, and to compensate for missing dynamic linking)
echo "Copying code ..."
cp -R /vagrant/scion-android go

# export main function as AndroidMain in all binaries
echo "Exporting main function ..."
for f in $MAIN_FILES; do
    grep -qxF 'func AndroidMain() { main() }' go/$f || echo 'func AndroidMain() { main() }' >> go/$f
done

# make every binary's library public so they can be used as dependencies
echo "Updating library visibilities ..."
for f in $BAZEL_FILES; do
    sed -E -i 's_"//visibility:private"_"//visibility:public"_' go/$f
done

# prepend binary name to every flag definition to avoid collisions
echo "Updating flag definitions ..."
for f in `find go -name '*.go'`; do
    [ ! -f $f.orig ] && sed -E -i.orig 's/(flag\.[^"]+")([^"]*)"/\1'$(echo $(dirname $f) | tr '/' '_' | sed -e 's/go_//')'_\2"/' $f
done

# the dispatcher socket path is hardcoded; instead, we want to read it from an environment variable
echo "Exposing dispatcher socket ..."
[ ! -f go/lib/sock/reliable/reliable.go.orig2 ] && (
	sed -E -i.orig2 's/import.*\(/import ("os"/' go/lib/sock/reliable/reliable.go && # add the "os" package
	sed -E -i 's/DefaultDispPath.*=.*//' go/lib/sock/reliable/reliable.go && # remove the hardcoded dispatcher socket path
	# re-add the path as environment variable
	echo >> go/lib/sock/reliable/reliable.go &&
	echo 'func getEnv(key, fallback string) string { if value, ok := os.LookupEnv(key); ok { return value }; return fallback }' >> go/lib/sock/reliable/reliable.go &&
	echo 'var ( DefaultDispPath = getEnv("DISPATCHER_SOCKET", "/run/shm/dispatcher/default.sock") )' >> go/lib/sock/reliable/reliable.go)

# remove obsolete select expression preventing Android builds (see https://github.com/scionproto/scion/pull/3325 )
echo "Removing select expression ..."
perl -0777 -pe 's/select\(.*?(\[.*?\]).*?\)/$1/gs' go/lib/overlay/conn/BUILD.bazel | sponge go/lib/overlay/conn/BUILD.bazel

# disable nogo linter (see https://github.com/bazelbuild/rules_go/issues/2172 , https://github.com/scionproto/scion/pull/3325 )
echo "Disabling linter ..."
[ ! -f WORKSPACE.orig ] && sed -E -i.orig 's/go_register_toolchains\(.*?nogo/# \0/' WORKSPACE

# update rules_go version (required for linkmode = "pie")
echo "Updating rules_go version ..."
perl -0777 -pe 's/(git_repository\(.*?name.*?=.*?"io_bazel_rules_go".*?tag.*?=.*?").*?"/$1'$RULES_GO_VERSION'"/gs' WORKSPACE | sponge WORKSPACE

# update gazelle version
echo "Updating gazelle version ..."
perl -0777 -pe 's#(http_archive\(.*?name.*?=.*?"bazel_gazelle".*?urls.*?=.*?\[.*?").*?(".*?\].*?sha256.*?=.*?").*?"#$1'$GAZELLE_URL'$2'$GAZELLE_SHA256'"#gs' WORKSPACE | sponge WORKSPACE

# register Android NDK with Bazel
echo "Registering Android NDK ..."
grep -qF 'android_ndk_repository' WORKSPACE || (echo >> WORKSPACE &&
	echo 'android_ndk_repository(name="androidndk", path="/home/vagrant/android-ndk")' >> WORKSPACE &&
	echo 'register_toolchains("@androidndk//:all")' >> WORKSPACE)

# if not present, add transitive dependency required by new rules_go version
# (taken from https://github.com/scionproto/scion/blob/v0.4.0/WORKSPACE , see https://github.com/bazelbuild/rules_go/issues/195 )
echo "Adding transitive dependency ..."
grep -qF 'org_golang_x_net' WORKSPACE || (echo >> WORKSPACE &&
	echo 'go_repository(name="org_golang_x_net", importpath="golang.org/x/net", sum="h1:QPlSTtPE2k6PZPasQUbzuK3p9JbS+vMXYVto8g/yrsg=", version="v0.0.0-20191105084925-a882066a44e0")' >> WORKSPACE)

# build SCION (Intel/AMD and ARM 32-bit and 64-bit for Android and a debug build for amd64 as well)
echo "Building SCION ..."
rm -f bazel-bin/go/scion-android/*/scion-android
yes | ./env/deps
make -C go/proto
bazel build //go/scion-android # debug build
cp bazel-bin/go/scion-android/linux_amd64_stripped_pie/scion-android /vagrant/test/libscion-$SCION_NAME.so
for platform in "${!PLATFORMS[@]}"; do
	# build with Bazel, use C crosscompiler provided by Android NDK
	bazel build //go/scion-android \
		--crosstool_top=@androidndk//:default_crosstool --host_crosstool_top=@bazel_tools//tools/cpp:toolchain --cpu="${PLATFORMS[$platform]}" \
		--platforms=@io_bazel_rules_go//go/toolchain:$platform

	# copy executable to destination, suitable to be imported in Android Studio
	export TARGET_DIR=/vagrant/jniLibs/${PLATFORMS[$platform]}
	mkdir -p $TARGET_DIR
	cp bazel-bin/go/scion-android/*/scion-android $TARGET_DIR/libscion-$SCION_NAME.so
	rm -f bazel-bin/go/scion-android/*/scion-android
done

popd > /dev/null
