# Changelog

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
