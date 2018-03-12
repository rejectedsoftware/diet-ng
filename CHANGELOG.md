Changelog
=========

v1.4.5 - 2018-03-12
-------------------

- Avoid singular tag enforcement for non-HTML documents - [issue #45][issue45], [pull #49][issue49]
- Always output empty XML elements using singular tag syntax - [pull #50][issue50]
- Fix broken XML doctype string (by Nicholas Wilson) - [pull #47][issue47]
- Fix deprecation warnings on DMD 2.079.0

Note: 1.4.3 and 1.4.4 just bumped the used vibe.d version of the examples.

[issue45]: https://github.com/rejectedsoftware/diet-ng/issues/45
[issue47]: https://github.com/rejectedsoftware/diet-ng/issues/47
[issue49]: https://github.com/rejectedsoftware/diet-ng/issues/49
[issue50]: https://github.com/rejectedsoftware/diet-ng/issues/50


v1.4.2 - 2017-08-26
-------------------

- Fixes "variable val is shadowing variable" errors when defining a variable `val` in a template - [issue #35][issue35]
- Fixes missing escaping for quotes in HTML attributes that are not typed `bool` or `string` - [issue #36][issue36]
- Tweaked the Meson build description to be usable as a sub project - [pull #39][issue39]

[issue35]: https://github.com/rejectedsoftware/diet-ng/issues/35
[issue36]: https://github.com/rejectedsoftware/diet-ng/issues/36
[issue39]: https://github.com/rejectedsoftware/diet-ng/issues/39


v1.4.1 - 2017-08-20
-------------------

- Adds a Meson project description (by Matthias Klumpp aka ximion) - [pull #37][issue37]

[issue37]: https://github.com/rejectedsoftware/diet-ng/issues/37


v1.4.0 - 2017-08-13
-------------------

- Implemented support for multi-line nodes (by Jan Jurzitza aka WebFreak) - [issue vibe.d#1307][issue1307_vibe.d]
- The shortcut syntax for class/id attributes is now allowed to start with a digit - [issue #32][issue32]

[issue32]: https://github.com/rejectedsoftware/diet-ng/issues/32
[issue1307_vibe.d]: https://github.com/rejectedsoftware/vibe.d/issues/1307


v1.3.0 - 2017-07-23
-------------------

- Heavily reduced the length of template symbol named generated during compilation, resulting in a lot less binary bloat
- Added support for a `.processors` field in traits structs that contains a list or arbitrary DOM modification functions
- Add DOM manipulation convenience functions


v1.2.1 - 2017-04-18
-------------------

- Fixed/implemented HTML white space inhibition using the `<`/`>` suffixes - [issue #27][issue27]

[issue27]: https://github.com/rejectedsoftware/diet-ng/issues/27


v1.2.0 - 2017-03-02
-------------------

- Added `compileHTMLDietFileString`, a variant of `compileHTMLDietString` that can make use of includes and extensions - [issue #24][issue24]
- Fixed a compile error for filter nodes and output ranges that are not `nothrow`
- Fixed extraneous newlines getting inserted in front of HTML text nodes when pretty printing was enabled

[issue24]: https://github.com/rejectedsoftware/diet-ng/issues/24


v1.1.4 - 2017-02-23
-------------------

- Fixes formatting of singluar elements in pretty HTML output - [issue #18][issue18]
- Added support for Boolean attributes that are sourced from a property/implicit function call (by Sebastian Wilzbach) - [issue #19][issue19], [pull #20][issue20]

[issue18]: https://github.com/rejectedsoftware/diet-ng/issues/18
[issue19]: https://github.com/rejectedsoftware/diet-ng/issues/19
[issue20]: https://github.com/rejectedsoftware/diet-ng/issues/20


v1.1.3 - 2017-02-09
-------------------

### Bug fixes ###

- Works around an internal compiler error on 2.072.2 that got triggered in 1.1.2


v1.1.2 - 2017-02-06
-------------------

### Features and improvements ###

- Class/ID definitions (`.cls#id`) can now be specified in any order - [issue #9][issue9]
- Block definitions can now also be in included files - [issue #14][issue14]
- Multiple contents definitions for the same block are now handled properly - [issue #13][issue13]

[issue9]: https://github.com/rejectedsoftware/diet-ng/issues/9
[issue13]: https://github.com/rejectedsoftware/diet-ng/issues/13
[issue14]: https://github.com/rejectedsoftware/diet-ng/issues/14


v1.1.1 - 2016-12-19
-------------------

### Bug fixes ###

- Fixed parsing of empty lines in raw text blocks


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
