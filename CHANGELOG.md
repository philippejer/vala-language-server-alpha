# Changelog

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
