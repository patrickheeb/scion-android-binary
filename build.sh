#!/bin/bash
set -e

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
export MAIN_FILES="posix-router/main.go cs/main.go dispatcher/main.go sciond/main.go scion-pki/main.go scion/scion.go  posix-gateway/main.go"
export BAZEL_FILES="posix-router/BUILD.bazel cs/BUILD.bazel dispatcher/BUILD.bazel sciond/BUILD.bazel scion-pki/BUILD.bazel scion/BUILD.bazel posix-gateway/BUILD.bazel"

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

# register Android NDK with Bazel
echo "Registering Android NDK ..."
grep -qF 'android_ndk_repository' WORKSPACE || (echo >> WORKSPACE &&
	echo 'android_ndk_repository(name="androidndk", path="/home/vagrant/android-ndk")' >> WORKSPACE &&
	echo 'register_toolchains("@androidndk//:all")' >> WORKSPACE)

# install docker and bazel
echo "Installing docker and bazel ..."
sudo ./tools/install_docker
./tools/install_bazel
sudo ./scion.sh bazel_remote
sudo chmod 777 -R /home/vagrant/.cache/bazel

# build SCION (Intel/AMD and ARM 32-bit and 64-bit for Android and a debug build for amd64 as well)
echo "Building SCION ..."
yes | ./env/deps
make gazelle
bazel build //go/scion-android # debug build
cp bazel-out/k8-fastbuild-ST-*/bin/go/scion-android/scion-android_/scion-android /vagrant/test/libscion-$SCION_NAME.so
sudo chmod 777 /vagrant/test/libscion-$SCION_NAME.so

for platform in "${!PLATFORMS[@]}"; do
	# build with Bazel, use C crosscompiler provided by Android NDK
	bazel build //go/scion-android \
		--crosstool_top=@androidndk//:default_crosstool \
		--host_crosstool_top=@bazel_tools//tools/cpp:toolchain \
		--cpu="${PLATFORMS[$platform]}" \
		--platforms=@io_bazel_rules_go//go/toolchain:$platform

	# copy executable to destination, suitable to be imported in Android Studio
	export TARGET_DIR=/vagrant/jniLibs/${PLATFORMS[$platform]}
	mkdir -p $TARGET_DIR
	cp bazel-out/${PLATFORMS[$platform]}-fastbuild-ST-*/bin/go/scion-android/scion-android_/scion-android \
		$TARGET_DIR/libscion-$SCION_NAME.so
done
sudo chmod 777 -R /vagrant/jniLibs/
popd > /dev/null
