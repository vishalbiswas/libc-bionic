#!/bin/bash
set -e

scriptdir="$(cd "$(dirname "$0")"; pwd)"
topdir="`pwd`/android_build"

googlebaseurl='https://android.googlesource.com/platform'

sources=('bionic' 'libnativehelper' 'build' 'build/kati' 'system/core' 'system/extras' 'external/jemalloc' 'external/libcxx' 'external/libcxxabi' 'external/elfutils'
         'external/llvm' 'external/libunwind_llvm' 'external/compiler-rt' 'external/safe-iop' 'external/google-benchmark' 'external/gtest' 'external/tinyxml2')
: ${buildref='nougat-release'}
: ${arch:=`uname -m`}
: ${skipsrc:='no'}
: ${skipndk:='no'}
# benchmarks are broken right now
: ${skipbenches:='yes'}
# zlib is not required for building
: ${skipzlib:='yes'}
ndkarch=$arch
gccarch=$arch
luncharch=$arch
gccver=4.9

abi="$arch-linux-android"

case $arch in
    x86) abi='x86_64-linux-android'; ndkarch='x86_64';;
    arm) abi+='eabi';;
    x86_64) gccarch='x86';;
    aarch64) ndkarch='arm64'; luncharch='arm64';;
esac

clangver=3.6
prebuilts=( "prebuilts/gcc/linux-x86/$gccarch/$abi-$gccver" "prebuilts/gcc/linux-x86/host/`uname -m`-linux-glibc2.15-4.8"
            'prebuilts/clang/host/linux-x86' 'prebuilts/gcc/linux-x86/host/x86_64-w64-mingw32-4.8' 'prebuilts/ninja/linux-x86' 'prebuilts/misc')

download_from_git () {
    echo "downloading $1"

    if [ -d "$topdir/$1" ]
      then
        rm -rf "$topdir/$1"
    fi
    mkdir -p "$topdir/$1"
    cd "$topdir/$1"

    git init -q
    git remote add origin "$googlebaseurl/$1"
    git fetch --depth 1 origin "$2" -q 
    git reset --hard FETCH_HEAD -q

    cd "$topdir"
}

if [ "$skipsrc" == 'no' ]
  then

mkdir -p "$topdir"
cd "$topdir"


for source in "${sources[@]}"
  do
    _buildref="$buildref"
    if [ "$source" == 'external/googletest' ]
      then
        _buildref='master'
    fi

        download_from_git "$source" "$_buildref"
done

cd "$topdir"

if [[ "$skipbenches" == 'yes' ]]
  then
    find bionic -type d -name 'benchmarks' -exec rm -r {} +
fi

for patch in $scriptdir/*.patch
  do
    patch -f -p1 < "$patch" || true
done

fi


if [ "$skipndk" == 'no' ]
  then
        _buildref="$buildref"
        for tool in "${prebuilts[@]}"
          do
            download_from_git "$tool" "$_buildref"
        done
rm -r prebuilts/misc/common/android-support-test || true
fi

source build/envsetup.sh
export JAVA_NOT_REQUIRED=true
lunch "aosp_$ndkarch-eng" > /dev/null

if [ "$skipzlib" == 'no' ]
  then
    download_from_git 'external/zlib' "$buildref"
    cd "$topdir/external/zlib"
    mma -j5
fi

cd "$topdir/bionic"
mma -j5

outdir="$topdir/out/target/product/generic"
test -d "${outdir}_$ndkarch" && outdir+="_$ndkarch"

cd "$outdir"
if [ "$skipzlib" == 'no' ]
  then
    outfile="$topdir/../bionic_${arch}_${buildref}_zlib.tar.xz"
else
    outfile="$topdir/../bionic_${arch}_${buildref}.tar.xz"
fi    

tar -cJf "$outfile" data system

set +e
