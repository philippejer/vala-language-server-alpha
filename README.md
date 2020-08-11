# Basic Language Server for Vala (deprecated)

**Note**: this project is very loosely maintained, please use and contribute to [this project](https://github.com/benwaffle/vala-language-server) which is actively developed. See paragraph below for more details on the state of Vala language servers.

## About the state of Vala Language Servers (2019-11-27)

I have started this project around july 2019 because I could not find a working language server on my setup (VSCode and MinGW). [This project](https://github.com/benwaffle/vala-language-server) from Ben Iofel seemed like a good starting point, so I have started modifying it with the intent of improving a few things (mostly wanted to get "go to definition" working correctly on my setup).

Since then, I have added quite a few features like basic completion support (in a very quick & dirty mode), and have been quite happy with the result. So I finally decided to publish it here in the hope that it would be useful to someone else.

However since then, two language server projects have seen a lot of activity:

- The original project from Ben Iofel, which seems to primarily target Vim: https://github.com/benwaffle/vala-language-server
- The GVls language server from Daniel Espinosa Ortiz, which seems to primarily target Gedit: https://gitlab.gnome.org/esodan/gvls

I have not yet had the time to check these projects out and see at what stage of maturity they are. GVls in particular has seen a lot of activity recently and the code looks very clean and professional, also the author clearly has a lot of experience in the Vala/GNOME ecosystem.

Since I do not intend to develop this project much further (aside from simple bug fixes and maybe some experiments), I would strongly advise to look at these two projects first and only use this one if they do not work for you.

## Prerequisites

Please note that this tool primarily targets VSCode as the client IDE and the project should ideally use Meson 0.50+ (the server will search for a valid `meson-info/intro-targets.json` file to determine the sources and compiler flags). It should also be built against a recent version of Vala (currently using version 0.46.3), since the Vala compiler API can change across versions (I have provided some step-by-step Ubuntu and MinGW-64 instructions below).

2019-10-20: A fallback is now available by adding a `vala-language-server.json` configuration file under the project root directory. This file will be detected and used to configure the list of sources files and/or directories and the compiler parameters (it is possible to simply copy the Vala compiler command line from e.g. `compile_commands.json`). An example configuration can be found [here](https://github.com/philippejer/vala-language-server-alpha/blob/master/vala-language-server-test.json).

2019-11-14: Committed workaround for [issue](https://github.com/philippejer/vala-language-server-alpha/issues/3#issuecomment-553895576) when starting Meson under Windows ("Meson did not return an array of targets...").

## Description

This is a basic language server for the [Vala](https://wiki.gnome.org/Projects/Vala) language, which is relatively limited in scope and mostly tailored to my specific setup (see requirements). I do not intend to polish it much further, however it feels usable enough that I have decided to publish the source code (the current Vala IDEs seem very limited and/or obsolete).

I am actually quite happy with the results as initially I only intended to improve the code navigation from the original [Vala language server](https://github.com/benwaffle/vala-language-server) (see [background section](#background) for details).

Note: the code uses many hacks and tricks (especially completion related stuff), this is quite deliberate as making a language server has never been a goal in itself for me, I have mostly used it as an opportunity to learn the language from the inside.

Currently it has only been "tested" with a specific setup:

* Visual Studio Code as the client IDE (other IDEs might work but I have not tested it)
* The project should be built with Meson 0.50+, as the language server uses Meson introspection to discover the source files and compiler options (this should be fairly common for current Vala projects)
* If Meson is not available or does not work, it is possible to use a `vala-language-server.json` config file (see above)
* The language server depends on Vala 0.47+ to parse and analyze the source files (other versions might work but this is the one I use)

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

## Limitations and known bugs

* If the Vala parser cannot parse the code (syntax error), code navigation will not work. For semantic errors, it does work, only the syntax needs to be correct. Note that I have made a compiler fork with a few experimental switches, in particular to allow the parser to ignore trivial syntax errors like missing semicolons (see below).

* The completion is a bit of a hack: to get around the fact that the parser most likely cannot parse the currently edited line of code, the expression just before the cursor is extracted "manually" (instead of relying on the parser, which is the first part of the hack), then the edited line is replaced by a fake "member access" expression (second part of the hack) and finally, the parser is run again to analyze that expression and infer a list of proposals. This approach may fail for various reasons, and then there will be no completion proposals. In pratice however, this approach does seem to work well in most practical situations, and has the advantage to be easier to implement (because the expression to inspect is guaranteed to be a member access expression, there is no need to handle the myriad of contexts where completion can be triggered).

* Symbol rename can fail to find every usage, use with care (it does work well in many common cases). Same thing with "find usages" since it shares the same logic.

* The dynamic diagnostics (errors and warnings) will only report syntax and semantic errors, not errors triggered during code generation, because code generation is very expensive. Fortunately, most errors are detected before code generation. An example of unseen error is passing the wrong type of delegate (with/without closure) to a method, which is currently only detected during code generation.

* Genie is not currently a target, however many things (code navigation) should already work, some of the more hack-ish things which rely on text-based heuristics (esp. completion) will probably not work (but could probably be made to work fairly easily).

## Experimental compiler branch

Note that [this branch](https://gitlab.gnome.org/philippejer/vala/tree/0.46.3-exp) contains a few experimental compiler switches (disabled by default), one in particular is a small modification of the parser to enable code navigation in the presence of trivial syntax errors like a missing semicolon (by default the syntax tree is not built in the presence of syntax errors).

The support of this "mode" in the compiler is detected by looking at the compiler version (see [meson.build](https://github.com/philippejer/vala-language-server-alpha/blob/master/meson.build)).

## How to compile for Linux (tested with Ubuntu 20.04)

Quick steps on how to compile and setup everything (last tested with fresh install of Ubuntu 20.04 on 11 august 2020).

### Install dependencies

* Install Meson
  * `sudo apt-get install meson`
* Install GLib and Valac (current version on Ubuntu 20.04 is 0.48.6 which is recent enough)
  * `sudo apt-get install libglib2.0-dev libgee-0.8-dev libjson-glib-dev libjsonrpc-glib-1.0-dev valac libvala-0.48-dev`

### Compile the language server

* Clone the repo
  * `git clone 'https://github.com/philippejer/vala-language-server-alpha.git'`
* Build
  * `meson build --buildtype=release && ninja -C build`
* Copy the language server on the `PATH` somewhere (or configure the extension to point to it)
  * `cp build/vala-language-server /usr/local/bin`

## How to compile for Windows (MSYS2-MinGW-64)

The general steps are quite similar with MSYS2-MinGW-64 (this is actually my main setup).

### Install MSYS2-MinGW-64

* Download from https://sourceforge.net/projects/msys2/files/Base/x86_64/
* Repeat the general update until there is nothing left to update (as explained in the [MSYS2 installation Wiki](https://sourceforge.net/p/msys2/wiki/MSYS2%20installation/))
  * `pacman -Syuu`
* Install some required build packages (some may not be strictly necessary for Vala)
  * `pacman -S base-devel`
  * `pacman -S vim mingw-w64-x86_64-toolchain mingw-w64-x86_64-make mingw-w64-x86_64-cmake mingw-w64-x86_64-python3-pip mingw-w64-x86_64-glib2 mingw-w64-x86_64-libgee mingw-w64-x86_64-vala`

### Install Meson

Vversion 0.50+ is required by the language server for build file introspection (there is also a fallback possible to use a plain `vala-language-server.json` file as explained above).

* Install Meson
  * `pip3 install meson`
* Check Meson installation
  * `meson --version` (current version is 0.54.3)

### Compile and install Vala from source (optional)

This is only useful if the current Vala compiler provided by the package is too out-of-date (currently version 0.48.6 is already provided).

* Download the pre-compiled Vala sources
  * `wget 'https://download.gnome.org/sources/vala/0.48/vala-0.48.6.tar.xz' && tar xf vala-0.48.6.tar.xz`
* Compile Valac
  * `cd vala-0.48.6 && ./configure && make`
* Install Valac
  * `make install`
* Workaround for some bug in libtool (presumably) which puts one DLL in the wrong directory
  * `mv /mingw64/lib/bin/libvalaccodegen.dll /mingw64/bin/ && rmdir /mingw64/lib/bin`

### Compile and install json-glib

Important: a recent master branch of this library (after 2020-01-14) is required to compile the language server (see [this commit](https://gitlab.gnome.org/GNOME/json-glib/commit/f2c5b4e2fec975b798ff5dba553c15ffc69b9d82) for more info).

* Checkout the repository
  * `git clone 'https://gitlab.gnome.org/GNOME/json-glib.git'`
  * `cd json-glib && git checkout 761de0f50a9954392ede2337c55e59adb28df97e`
* Build and install locally
  * `meson --buildtype plain -Ddocs=true -Dman=true build && ninja -C build`
  * `DESTDIR=/mingw64 ninja -C build install`

### Compile and install jsonrpc-glib

* Checkout the repository
  * `git clone 'https://gitlab.gnome.org/GNOME/jsonrpc-glib.git'`
  * `cd jsonrpc-glib && git checkout 3.34.0`
* Build and install locally
  * `meson --buildtype plain -Denable_tests=false -Dwith_introspection=true -Denable_gtk_doc=false build && ninja -C build`
  * `DESTDIR=/mingw64 ninja -C build install`

### Compile the language server

* Clone the repo
  * `git clone 'https://github.com/philippejer/vala-language-server-alpha.git'`
* Build
  * `meson build --buildtype=release && ninja -C build`
* Copy the language server on the `PATH` somewhere (or configure the extension to point to it)
  * `cp build/vala-language-server.exe /mingw64/bin`

## Install the client extension in VS Code

* Clone the repo
  * `git clone 'https://github.com/philippejer/vala-language-server-alpha.git'`
* Build the extension
  * `npm i -g vsce`
  * `npm i`
  * `vsce package`
* Install the extension ("Install from VSIX")

## Terminal popup issue under Windows / MSYS2-MinGW-64

It is likely that you'll have some annoying terminal popup issues under Windows / MSYS2-MinGW-64.

A recent bugfix in the Vala compiler (https://gitlab.gnome.org/GNOME/vala/blob/2ad4a6e8a6c7bf6b2a9fd5d825ad639c420df489/vala/valasourcefile.vala) has had the side effect that the Vala compiler will now properly check the package versions (this is apparently used to check for things like deprecated APIs in VAPIs etc.).

The problem under MSYS2-MinGW-64 is that this requires a call to the shell with `g_spawn ()` and since the language server is apparently seen by GLib as a UI application (as launched by VSCode anyway), GLib uses a "helper" to open a terminal and get the output of the command, which leads to these annoying terminal popups.

For now, my quick-and-dirty solution is to replace the non-console version of the helper with the console version of the helper with something like this (the call to the shell by the Vala compiler will still work for some reason):

`cp /mingw64/bin/gspawn-win64-helper.exe /mingw64/bin/gspawn-win64-helper.exe.bak && cp /mingw64/bin/gspawn-win64-helper-console.exe /mingw64/bin/gspawn-win64-helper.exe`

WARNING: this will probably many uses of `g_spawn ()` (not really sure, I mostly use MSYS2 for Vala development currently). Maybe playing with the `PATH` variable when starting the language server from the IDE would allow to do this properly (?).

## TODOs

* Comment the many and hack-ish obscure parts of the code (CodeHelpers in particular).
* General refactoring (some parts could be decoupled).

## Background

I have originally started this as a fork of this [Vala Language Server](https://github.com/benwaffle/vala-language-server) (around june 2019), which did not seem actively developped at the time. Initially I only wanted to see if I could improve on a few things but ended up adding quite a few features (and many hacks...).

Since then it seems the original repository has seen much more activity and is quite ambitious, for example with the goal of adding a "language server" mode to the Vala parser to properly implement code completion instead of relying on ugly text-based hacks like here. This is not an attempt to replicate this effort, the goal of this project has only been to make it usable for my specific use case with no other ambition (although I believe it is good enough to be useful to someone else).
