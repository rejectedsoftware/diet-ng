Changelog
=========

v1.8.0 - 2021-07-27
-------------------

- The translation callback can now take an optional `context` parameter with the name of the source template - [pull #92][issue92]
- Added a "makepot" tool to extract translation keys from a set of Diet template files - [pull #92][issue92]

[issue92]: https://github.com/rejectedsoftware/diet-ng/issues/92


v1.7.4 - 2020-09-03
-------------------

- Fix documentation build and update test settings - [issue #87][issue87]

[issue87]: https://github.com/rejectedsoftware/diet-ng/issues/87

v1.7.3 - 2020-09-02
-------------------

- Fix a deprecated Nullable alias this instance - [issue #84][issue84]
- Add support for DMD 2.094 `-preview=in` switch - [issue #85][issue85]
- Update release notes & meson build for v1.7.3 - [issue #86][issue86]

[issue84]: https://github.com/rejectedsoftware/diet-ng/issues/84
[issue85]: https://github.com/rejectedsoftware/diet-ng/issues/85
[issue86]: https://github.com/rejectedsoftware/diet-ng/issues/86

v1.7.2 - 2020-03-25
-------------------

- Add back in import for `std.conv.to` - [issue #82][issue82]

[issue82]: https://github.com/rejectedsoftware/diet-ng/issues/82


v1.7.1 - 2020-03-24
-------------------

- Fixed an issue where the translation callback had to be marked `@safe` - [pull #80][issue80]
- Updates the Meson version number of the package - [issue #79][issue79], [pull #80][issue80]

[issue79]: https://github.com/rejectedsoftware/diet-ng/issues/79
[issue80]: https://github.com/rejectedsoftware/diet-ng/issues/80


v1.7.0 - 2020-03-24
-------------------

- Adds support for a new "live mode" (by Steven Schveighoffer) - [pull #70][issue70], [pull #78][issue78]
	- Enabled by defining a version `DietUseLive`
	- Allows changes to the template to be reflected immediately at runtime
	- Only pure HTML changes are supported, changing embedded code will require a re-compile
	- Can greatly reduce the edit cycle during development - should not be used for production builds
- Avoids redundant template compilations for templats instantiated with the same parameters (by Steven Schveighoffer) - [pull #77][issue77]
- Fixed a possible range violation error (by Steven Schveighoffer) - [issue #75][issue75], [pull #76][issue76]

[issue70]: https://github.com/rejectedsoftware/diet-ng/issues/70
[issue75]: https://github.com/rejectedsoftware/diet-ng/issues/75
[issue76]: https://github.com/rejectedsoftware/diet-ng/issues/76
[issue77]: https://github.com/rejectedsoftware/diet-ng/issues/77
[issue78]: https://github.com/rejectedsoftware/diet-ng/issues/78


v1.6.1 - 2019-10-25
-------------------

- Fixes the "transitional" HTML doctype string (by WebFreak) - [pull #60][issue60]
- Compiles without deprecation warnings on DMD 2.088.0 - [pull #66][issue66]
- Fixes the use of C++ style line comments in code lines - [issue #58][issue58], [pull #73][issue73]
- Avoids excessive CTFE stack traces when syntax errors are encountered - [issue #69][issue69], [pull #73][issue73]

[issue58]: https://github.com/rejectedsoftware/diet-ng/issues/58
[issue60]: https://github.com/rejectedsoftware/diet-ng/issues/60
[issue66]: https://github.com/rejectedsoftware/diet-ng/issues/66
[issue69]: https://github.com/rejectedsoftware/diet-ng/issues/69
[issue73]: https://github.com/rejectedsoftware/diet-ng/issues/73


v1.6.0 - 2019-08-16
-------------------

- Adds the new "extension includes" feature, combining blocks/extensions with includes - [pull #64][issue64]
- Adds `Node.clone` and `NodeContent.clone` for recursive DOM cloning - [pull #64][issue64]
- Updates compiler support to DMD 2.082.1 up to 2.087.1 and LDC 1.12.0 up to 1.16.0 - [pull #64][issue64]

[issue64]: https://github.com/rejectedsoftware/diet-ng/issues/64


v1.5.0 - 2018-06-10
-------------------

- Adds `Node.translationKey` to allow external code to access the original translation key for translated nodes - [pull #55][issue55]

[issue55]: https://github.com/rejectedsoftware/diet-ng/issues/55


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
