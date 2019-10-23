# How to install from release (Windows, MinGW-w64)

* Unzip the release in e.g. `C:\vala-language-server`.

* Every DLL required by `vala-language-server.exe` (especially the compiler DLLs and the compiler-provided VAPIs) come (or have been compiled with) MinGW-w64 and are included to avoid any ABI compatibility issues. Note that one of the drawbacks (curently) is that the compiler DLL will not "see" the standard VAPI directory (`C:\msys64\mingw64\share\vala\vapi`). So if you install additional Vala libraries, you'll have to make sure to copy the corresponding VAPI files to `C:\vala-language-server\share\vala\vapi`.

* As explained in the README, the project is expected to use Meson 0.50+ as the build system (the server searches for a `meson.build` file and a `build.ninja` file under the project root or one of its sub-directories).

* Fallback: if the project does not use Meson, it is also possible to create a `vala-language-server.json` at the root of the project ithw the sources and compiler switches. Here is an [example](https://github.com/philippejer/vala-language-server-alpha/blob/master/vala-language-server-test.json).

* Install the VSCode [extension](https://marketplace.visualstudio.com/items?itemName=philippejer.vala-language-client).

* Add the following to your `settings.json`

```json
  "vls.path.server": "C:\\vala-language-server\\bin\\vala-language-server.exe",
  "vls.debug.server": "warn",
  "vls.trace.server": "off",
```
