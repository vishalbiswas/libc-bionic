# libc-bionic
This repository contains scripts to build bionic libc (used in Android) only.

I was unable to find any documentation to build just bionic, which gave rise to this.

Please install `python2`, `libc-dev-i386` and `g++-multilib` first.

Building under Linux subsystem for Windows is not supported, yet. The subsystem cannot
run 32-bit executables generated while building.

Only the latest nougat-release branch is supported as of now. I'm open to pull requests
adding support for older ones. As a consequence, the build system will use ninja, which
is mandatory post Marshmallow releases.