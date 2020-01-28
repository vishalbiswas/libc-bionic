# Android Bionic Libc Standalone build

This repository contains scripts to build standalone **Bionic Libc** - the C Runtime Library used in Android. I was unable to find any documentation to build bionic alone, which gave rise to this.

## Prerequisites

Please install `python2`, `libc-dev-i386` and `g++-multilib` first.

## Build

Execute the script, specifying the target configuration:

```
arch=arm ./build.sh
```

The resulting libraries with be placed into `./android_build/out/target/product/generic/obj/lib`.

## Status

Building under Linux subsystem for Windows (WSL) is not supported, yet. The subsystem cannot run 32-bit executables generated while building.

Only the latest Nougat release branch is supported as of now. I'm open to pull requests adding support for older ones. As a consequence, the build system will use `ninja`, which is mandatory post Marshmallow releases.
