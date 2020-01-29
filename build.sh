#!/bin/bash
set -e

scriptdir="$(cd "$(dirname "$0")"; pwd)"
topdir="`pwd`/android_build"

googlebaseurl='https://android.googlesource.com/platform'
tgzbaseurl="$googlebaseurl/@SOURCE@/+archive/@BUILDREF@.tar.gz"

sources=('bionic' 'libnativehelper' 'build' 'build/kati' 'system/core' 'external/jemalloc' 'external/libcxx' 'external/libcxxabi' 'external/zlib'
         'external/iputils' 'external/elfutils' 'external/llvm' 'external/libunwind_llvm' 'external/compiler-rt' 'external/safe-iop' 'external/gtest')
: ${buildref='nougat-release'}
: ${arch:=`uname -m`}
: ${usetgz:='yes'}
: ${skipsrc:='no'}
: ${skipindeps:='no'}
: ${skipcross:='no'}
# benchmarks are broken right now
: ${skipbenches:='yes'}
: ${skiptests:='yes'}
# extra utilities like zlib, ping
: ${skiputil:='yes'}
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
prebuilts=( "prebuilts/gcc/linux-x86/host/`uname -m`-linux-glibc2.15-4.8" 'prebuilts/clang/host/linux-x86'
            'prebuilts/gcc/linux-x86/host/x86_64-w64-mingw32-4.8' 'prebuilts/ninja/linux-x86')

download () {
    echo "downloading $1"

    if [ -d "$topdir/$1" ]
    then
        rm -rf "$topdir/$1"
    fi
    mkdir -p "$topdir/$1"
    cd "$topdir/$1"

    if [ "$usetgz" == 'no' ]
    then
        download_from_git $@
    else
        download_tarball $@
    fi

    cd "$topdir"
}

download_from_git () {
    git init -q
    git remote add origin "$googlebaseurl/$1"
    git fetch --depth 1 origin "$2" -q 
    git reset --hard FETCH_HEAD -q
}

download_tarball () {
    tarfile="/tmp/`basename $1`.tgz"
    curl -sL $(echo $tgzbaseurl | sed -e "s|@SOURCE@|$1|" -e "s|@BUILDREF@|$2|") -o $tarfile
    tar -xf $tarfile
    rm $tarfile
}

download_single_folder () {
    echo "downloading $1/$3"
    if [ -d "$topdir/$1" ]
    then
        rm -rf "$topdir/$1"
    fi
    mkdir -p "$topdir/$1/$3"
    cd "$topdir/$1/$3"

    download_tarball $1 $2/$3
    
    cd "$topdir"
}

if [ "$skipsrc" == 'no' ]
then

    mkdir -p "$topdir"
    cd "$topdir"


    for source in "${sources[@]}"
    do
	_buildref="$buildref"
	download "$source" "$_buildref"
    done

    cd "$topdir"

    if [[ "$skipbenches" == 'yes' ]]
    then
	find bionic -type d -name 'benchmarks' -exec rm -r {} +
    else
	download 'external/google-benchmark' $buildref
    fi

fi

if [[ "$skiptests" == 'yes' ]]
then
    cd "$topdir"
    rm -r bionic/libc/malloc_debug || true

    #this and some other tests are essential for build as they are in main Android.mk
    tests=( 'system/core/libnativebridge/tests' 'libnativehelper/tests' 'external/compiler-rt/lib/sanitizer_common/tests' 'system/core/libmincrypt/test' )

    for required_test in "${tests[@]}"
    do
        mv $required_test ${required_test}1 || true
    done

    find . -type d -name 'tests' -prune -exec rm -r {} +
    find . -type d -name 'test' -prune -exec rm -r {} +

    for required_test in "${tests[@]}"
    do                 
        mv ${required_test}1 $required_test || true
    done

else
    download 'system/extras' $buildref
    download 'external/tinyxml2' $buildref
fi

for patch in $scriptdir/*.patch
do
    patch -f -p1 < "$patch" || true
done



if [ "$skipindeps" == 'no' ]
then
    _buildref="$buildref"
    for tool in "${prebuilts[@]}"
    do
        download "$tool" "$_buildref"
    done
    rm -r prebuilts/misc/common/android-support-test || true
    

    if [ "$usetgz" == 'no' ]
    then
        download 'prebuilts/misc' $_buildref
    else
        download_single_folder 'prebuilts/misc' $_buildref 'linux-x86/relocation_packer'
    fi
fi

if [ "$skipcross" == 'no' ]
then
    crossgcc="prebuilts/gcc/linux-x86/$gccarch/$abi-$gccver"
    download $crossgcc $buildref
fi

cd "$topdir"

source build/envsetup.sh
lunch "aosp_$ndkarch-eng" > /dev/null
m clobber

if [ "$skiputil" == 'no' ]
then
    #cd "$topdir/external/zlib"
    m libz -j5
    mmm external/iputils
fi

#cd "$topdir/bionic"
m -j5 libc libc++ libdl libm libstdc++ liblog libbase linker

outdir="$topdir/out/target/product/generic"
test -d "${outdir}_$ndkarch" && outdir+="_$ndkarch"

cd "$outdir"
if [ "$skiputil" == 'no' ]
then
    outfile="$topdir/../bionic_${arch}_${buildref}_utils.tar.xz"
else
    outfile="$topdir/../bionic_${arch}_${buildref}.tar.xz"
fi    

tar -cJf "$outfile" system

set +e
