# Basic Language Server for Vala

## Foreword

To be clear, the goal of this tool is to get 90% of the job done in as little code as possible. Otherwise, it would not be manageable since for me this is only a tool and not a goal in itself (although it has been quite a fun project).

I do not intend to go the last 10% percent here because that would require exponentially more work (but I will gladly do my best to fix bugs and do simple improvements on the existing features).

Now, obviously anyone can fork the code and extend it but I think middle/long term development should really go towards [the original project](https://github.com/benwaffle/vala-language-server), which has a broader scope (like supporting other IDEs, other build systems, etc.).

I certainly hope to have the time to contribute some PRs there.

Also please note that this tool currently assumes that the client IDE is the latest version of VS Code and that the project is built with Meson 0.50+ (the project must have a valid `meson.build` file). It also should be built against a recent version of Vala due to various improvements and bugfixes made recently (step-by-step Ubuntu and MinGW-64 instructions detailed below).

## Description

This is a basic language server for the [Vala](https://wiki.gnome.org/Projects/Vala) language, which is relatively limited in scope and mostly tailored to my specific setup (see requirements). I do not intend to polish it much further, however it feels usable enough that I have decided to publish the source code (the current Vala IDEs seem very limited and/or obsolete).

I am actually quite happy with the results as initially I only intended to improve the code navigation from the original [Vala language server](https://github.com/benwaffle/vala-language-server) (see [background section](#background) for details).

Note: the code uses many hacks and tricks (especially completion related stuff), this is quite deliberate as making a language server has never been a goal in itself for me, I have mostly used it as an opportunity to learn the language from the inside.

Currently it has only been "tested" with a specific setup:

- Visual Studio Code as the client IDE (other IDEs might work but I have not tested it)
- The project should be built with Meson 0.50+, as the language server uses Meson introspection to discover the source files and compiler options (this should be fairly common for current Vala projects)
- The language server depends on Vala 0.46+ to parse and analyze the source files (other versions might work but this is the one I use)

I have written a quick step-by-step guide on [how to compile](#how-to-compile) the language server starting from a vanilla Ubuntu distribution (18.04) and the same with MinGW-64 under Windows.

## Supported language server features

![Demo](https://github.com/philippejer/vala-language-client-alpha/raw/master/images/demo.gif?raw=true)

The following features work reasonably well (for my requirements anyway):

* Document validation (error highlighting)
* Go to definition (code navigation)
* Mouse hover (symbol declaration)
* Document symbols (outline)
* Find references / symbol rename (rename support is limited, use with care)
* Code completion (crude and hack-ish but still fairly fast and usable in common situations)

## How to compile (Ubuntu 18.04)

Quick steps on how to compile and setup everything (tested with Ubuntu 18.04)

### Compile Valac

* Install required build packages
  * `sudo apt-get install build-essential cmake autoconf autoconf-archive automake libtool flex bison libgraphviz-dev libgee-0.8-dev libjsonrpc-glib-1.0-dev`
* Download the pre-compiled Vala sources
  * `wget 'http://download.gnome.org/sources/vala/0.46/vala-0.46.0.tar.xz' && tar xf vala-0.46.0.tar.xz`
* Compile Valac
  * `cd vala-0.46.0 && ./configure && make`
* Install Valac (under `/usr/local`)
  * `sudo make install`
* Check the installation
  * `valac --version` (requires `/usr/local/bin` on `PATH`)
* For some reason I have had to rebuild the dynamic library cache once
  * `sudo rm -f /etc/ld.so.cache ; sudo ldconfig`

### Install Meson (version 0.50+ is required by the language server for build file introspection)

* Install Python
  * `sudo apt-get install python3 python3-pip python3-setuptools python3-wheel ninja-build`
* Install Meson
  * `sudo pip3 install meson`
* Check Meson installation
  * `meson --version` (currently using 0.51.2)

### Compile the language server

* Clone the repo
  * `git clone 'https://github.com/philippejer/vala-language-server-alpha.git'`
* Build
  * `meson build --buildtype=release && ninja -C build`
* Copy the language server on the `PATH` somewhere (or configure the extension to point to it)
  * `cp build/vala-language-server /usr/local/bin`

## How to compile (MinGW-64)

The general steps are quite similar with MinGW-64 (this is actually my main setup).

### Install MinGW-64

* Download from https://sourceforge.net/projects/msys2/files/Base/x86_64/
* Repeat the general update until there is nothing left to update (as explained in the [MSYS2 installation Wiki](https://sourceforge.net/p/msys2/wiki/MSYS2%20installation/))
  * `pacman -Syuu`
* Install some required build packages (some may not be strictly necessary for Vala)
  * `pacman -S base-devel`
  * `pacman -S vim mingw-w64-x86_64-toolchain mingw-w64-x86_64-make mingw-w64-x86_64-cmake`

### Compile Valac

Note: you can skip this step by installing the recently updated vala compiler (0.46.3) from the package repository (`pacman -S mingw-w64-x86_64-vala`)

* Download the pre-compiled Vala sources
  * `wget 'http://download.gnome.org/sources/vala/0.46/vala-0.46.0.tar.xz' && tar xf vala-0.46.0.tar.xz`
* Compile Valac
  * `cd vala-0.46.0 && ./configure && make`
* Install Valac
  * `make install`
* Workaround for some bug in libtool (presumably) which puts one DLL in the wrong directory
  * `mv /mingw64/lib/bin/libvalaccodegen.dll /mingw64/bin/ && rmdir /mingw64/lib/bin`

### Install Meson (version 0.50+ is required by the language server for build file introspection)

* Install Python
  * `pacman -S mingw-w64-x86_64-python3-pip`
* Install Meson
  * `pip3 install meson`
* Check Meson installation
  * `meson --version` (currently using 0.52.0)

### Compile the language server

* Clone the repo
  * `git clone 'https://github.com/philippejer/vala-language-server-alpha.git'`
* Build
  * `meson build --buildtype=release && ninja -C build`
* Copy the language server on the `PATH` somewhere (or configure the extension to point to it)
  * `cp build/vala-language-server.exe /mingw64/bin`

### Install the client extension in VS Code

https://marketplace.visualstudio.com/items?itemName=philippejer.vala-language-client

## TODOs

* Comment the many and hack-ish obscure parts of the code (CodeHelpers in particular).
* General refactoring (some parts could be decoupled).

## Background

I have originally started this as a fork of this [Vala Language Server](https://github.com/benwaffle/vala-language-server) (around june 2019), which did not seem actively developped at the time. Initially I only wanted to see if I could improve on a few things but ended up adding quite a few features (and many hacks...).

Since then it seems the original repository has seen much more activity and is quite ambitious, for example with the goal of adding a "language server" mode to the Vala parser to properly implement code completion instead of relying on ugly text-based hacks like here. This is not an attempt to replicate this effort, the goal of this project has only been to make it usable for my specific use case with no other ambition (although I believe it is good enough to be useful to someone else).
