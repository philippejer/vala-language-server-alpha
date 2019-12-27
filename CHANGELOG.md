# Changelog

## 1.2.0
- Major improvement in how code lens or document symbol requests are processed when the source code is being edited, wait for the compiler context to be updated before answering the request (otherwise the request will be processed with an out-of-date compiler context and will return bogus results).
- Related to this, properly handle the (non standard) 'cancel' notifications sent by the client when the server does not answer these requests immediately.
- Do not show instance symbols for completion inside static methods.
- Added support for multiple executable build targets, the currently active executable target is switched dynamically based on the opened files.
- Fixed race condition where the completion could alter the compiler context while the diagnostics are being sent to the client
- Added lint to avoid use of the 'var' keyword (for those like me who think it makes the code less readable) and replace it with the actual type
- Added lint to cast to non-null when required by the non-null mode (almost never required with the experimental "null exemption" compiler mode which lets the compiler infer that a variable can never be null, otherwise it requires way too many casts which make the code less readable)
- Adapted the code to compile in non-null (but only when using the "null exemption" mode)

## 1.1.0
- Simplify Meson-base configuration by simply directly reading the 'intro-targets.json' instead of spawning Meson, which did not work well under MinGW.
- Added support for code lints, with two initial lints to enforce explicit "this" access and/or explicit static member access.
- Added support for dynamic settings between client and server (ServerConfig), allowing to change the log level on the fly without reloading the window (requires an update of the client VSCode extension).
- Added code lens support for references to methods and properties (similar to how C# is handled, command is specific to VSCode however).
- Added some checks to avoid renaming a symbol if the target name is already defined in the scope of one of the references (maybe too conservative since it would compile in some cases, however overloading a name from the parent scope is generally considered bad practice these days anyway).
- Fix potential performance issue in FindNode-derived code visitors, where the same nodes could be visited many times, by checking for already visited node in the base class (also to avoid logic duplication).
- Fix bug where constructors were not found by code navigation (navigated to the parent class instead).
- Fix bug where member initializers were not found by code visitors, making them invisible to code navigation, references and renaming (bug will be reported in Vala but worked around for now).
- Refactored some global functions into static helper classes, and added explicit public/private modifiers, in an attempt to avoid duplication in the generated C code (when combined with the --use-header switch) and hopefully make the "unity" build mode of Meson work someday (this will require some modifications of the Vala compiler, since it seems it replicates common string/array functions in each generated file).
- Refactored logs to make them more readable (hopefully).

## 1.0.4
- Fix issue with Meson command failing under MinGW because the wrong GLib helper process is used.

## 1.0.3
- Fix bug where some static members are not in the completions (e.g. float.max()).
- Disable rename when there are compiler errors.
- Add support for auto-insert of parentheses in method completion.
- Improved "resilient" parser mode with the '-exp' compiler fork (missing identifiers).

## 1.0.2
- Add directory support in config file.

## 1.0.1
- Fixed possible infinite loop in the modified Vala parser in "resilient" mode.
  - Only impacts the binary release and people using the modified compiler library.

## 1.0.0
- Version tagged to help with [issue #3](https://github.com/philippejer/vala-language-server-alpha/issues/3).
- Tentative binary release (MinGW-w64 only ).

## 2019-10-19
- Lots of cleanup, code re-organization in sub-folders and helper classes.
- Many (relatively minor) bugfixes and improvements:
  - Completion symbols are now ordered (inherited symbols like those from `GLib.Object` are displayed below the direct members).
  - Fixed bug in document symbols (symbols mixed up in some VAPI files).
  - Fixed completion not working for error codes.
  - Use markdown in the code snippets (hover, etc.).
  - Added support for the experimental "resilient parser" (compiler branch) flag to allow code navigation in the presence of syntax errors.  
  - Finer grained log level (debug/info/warn/off), configured via the `VLS_DEBUG` environment variable.

## 2019-10-07
- Initial commit
