Changelog
=========

v1.1.0 - 2016-09-29
-------------------

This release adds support for pretty printing and increases backwards
compatibility with older DMD front end versions.

### Features and improvements ###

- Compiles on DMD 2.068.0 up to 2.071.2
- Supports pretty printed HTML output by inserting a `htmlOutputStyle` field
  in a traits struct - [issue #8][issue8]

[issue8]: https://github.com/rejectedsoftware/diet-ng/issues/8


v1.0.0 - 2016-09-22
-------------------

This is the first stable release of diet-ng. Compared to the original
`vibe.templ.diet` module in vibe.d, it offers a large number of
improvements.

### Features and improvements ###

- No external dependencies other than Phobos
- Extensible/configurable with traits structures
- Supports inline and nested tags syntax
- Supports string interpolations within filter nodes (falls back to
  runtime filters)
- Supports arbitrary uses other than generating HTML, for example we
  use it similar to QML/XAML for our internal UI framework
- The API is `@safe` and `nothrow` where possible
- Uses less memory during compilation
- Comprehensive unit test suite used throughout development
- Supports AngularJS special attribute names
