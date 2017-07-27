Diet Language Specification
===========================

(NOTE: This specification is not yet complete. To fill the gaps, you can orient yourself using the [documentation on vibed.org](https://vibed.org/templates/diet) and the [pugjs reference](https://pugjs.org/api/reference.html)).

Synopsis
--------

This is an example of a simple Diet HTML template:

	doctype html
	- auto title = "Hello, <World>";
	html
		head
			title #{title} - example page
		body
			h1= title

			h2 Index
			ol.pageindex
				- foreach (i; 0 .. 3)
					li: a(href="##{i}") Point #{i}

			- foreach (i; 0 .. 3)
				h2(id=i) Point #{i}
				p.
					These are the #[i contents] of point #{i}. Multiple
					lines of text are contained in this paragraph.

The generated HTML code will look like this:

	<!DOCTYPE html>
	<html>
		<head>
			<title>Hello, &lt;World&gt; - example page</title>
		</head>
		<body>
			<h1>Hello, &lt;World&gt;</h1>
			<h2>Index</h2>
			<ol class="pageindex">
				<li><a href="#0">Point 0</a></li>
				<li><a href="#1">Point 1</a></li>
				<li><a href="#2">Point 2</a></li>
			</ol>
			<h2 id="0">Point 0</h2>
			<p>These are the <i>contents</i> of point 0. Multiple
			lines of text are contained in this paragraph.</p>
			<h2 id="1">Point 1</h2>
			<p>These are the <i>contents</i> of point 1. Multiple
			lines of text are contained in this paragraph.</p>
			<h2 id="2">Point 2</h2>
			<p>These are the <i>contents</i> of point 2. Multiple
			lines of text are contained in this paragraph.</p>
		</body>
	</html>


Indentation
-----------

Diet templates are a hierarchical data format, where the nesting of the data is determined using the line indentation level (similar to Python). The indentation style is determined from the first line in the file that is indented. The sequence of space and tab characters prefixed to the line's contents will be taken as a template for all following lines.

The white space in front of all lines in the document must be a multiple of this whitespace sequence (concatenation). The only exceptions are the nested contents of comments and text nodes.


Tags
----

A tag consists of the following parts, which, if present, must occur in the listed order:

  - **Tag name**

    The name must be an *identifier*, that may additionally contain the following characters: `-_:`. Without any additional parts this will output an element `<identifier>` or if it can have children (everything except a few selected [HTML tags](source/diet/html.d#291)) it will surround the children with `<identifier></identifier>` instead. The tag name can be omitted if an element ID or a class name is present, in which case it will default to `div` for HTML templates.

  - **Element ID**

    The ID must be prefixed by a `#` character and must be a valid *identifier* with the following additionally permitted characters: `-_`. For HTML templates, the ID will be output as an "id" attribute of the HTML element. There must only be one ID per element. If the tag name has been omitted but an ID is present, the tag name will be `div` for HTML templates.

  - **Style class list**

    List of class names, where each class name is prefixed by a `.`. A class name must be a valid *identifier* with the following additionally permitted characters: `-_`. For HTML templates, multiple class names will be merged into a single "class" attribute (classes separated by space characters). If the tag name has been omitted but at least one class name is present, the tag name will be `div` for HTML templates.

  - **Attribute list**
    
    List of attributes of the form `(att1=value, att2)`. Attributes can have new lines but the children must still be indented as usual. An attribute name must be a valid *identifier*. The value part can take any of the following forms:

    - a valid D expression

      ```d
      a(href=user.url) Me
      // Generates (user = {url: "/bob"})
      <a href="/bob">Me</a>
      ```

      which gets compiled into the executable and can use runtime values passed via the render function, see [Embedded D code](#embedded-d-code).

    - a string literal with double-quotes `"` or single-quotes `'`, which may contain *interpolations*

      ```d
      img(src="/images/avatar_#{picture.id}.png")
      // Generates (picture = {id: 4})
      <img src="/images/avatar_4.png"/>
      ```

    - a boolean value or no value part. It looks like a normal HTML5 shortened attribute but will generate valid XHTML attributes.

      ```d
      button(enabled)
      button(enabled=false)
      // Generates
      <button enabled="enabled"></button>
      <button></button>
      ```

  - **Whitespace-removal directives**

    - A single `<` will instruct the generator not to emit additional white space within the generated HTML element.
    ```html
    div
    foo>
      a bar
    // Generates
    <div></div>
    <foo><a>bar</a></foo>
    ```
    - A single `>` will instruct the generator not to emit additional white space around the generated HTML element.
    ```html
    div
    foo<
      a bar
    // Generates
    <div></div><foo>
      <a>test</a>
    </foo>
    ```

    You might also combine both whitespace-removal directives using `<>` or `><` which will get rid of all whitespaces associated with the tag inside the generated HTML. You can use this for example for a horizontal row of elements or buttons that shouldn't have any spaces in between them.

  - **Translation directive**

    A single `&` will mark the node's contents to be subject to translation (in i18n contexts)

    ```
    h1& website.title
    ```

    To implement the translate function you need to add a `static string translate(string text)` which must work at compile time inside your diet context.

    ```d
    @dietTraits
    struct Context {
      static string translate(string text) {
        return text == "Hello, World!" ? "Hallo, Welt!" : text;
      }
    }
    auto dst = appender!string;
    dst.compileHTMLDietFile!("diet.dt", Context);
    ```

    or when using inside vibe.d you use it with a `translationContext`.

Instead of a tag you may also place a `| text` node which will insert the raw text (`text` in this case) into the HTML document. You can use this to set a tag content to a combination of tags and text, or you could use foreach loops adding text with this, etc. Adding a second space will start inserting actual spaces into the inserted text as only everything after the `| ` is consumed, see [Text nodes](text-nodes).

All parts are optional, except that at least one of tag name, id, or class name must be present. The text that follows the tag definition determines how the following text is interpreted when determining the node's contents:

  - Directly followed by `:`: Another tag can be put on the same line and will be nested: `li: a(href="https://...") link`
  - Directly followed by `!=`, the rest of the line is treated as a D expression that will be converted to a string and is then output verbatim in the result
  - Directly followed by `=`, the rest of the line is treated as a D expression that will be converted to a string and is then output in escaped form (HTML escaped for the HTML generator)
  - Directly followed by a dot (`.`), the following nested lines will all be treated as text, without using explicit *text nodes*.
  - Followed by a space character, the rest of the line is treated as text contents with the possibility to insert *interpolations* and *inline tags*

### Identifiers

TODO!


### Inline tags

Within text contents it is possible to insert nested nodes within the same line by enclosing them in `#[...]`. The syntax is the same as for normal tags, except that the `:` and `.` suffixes are not permitted.

Example: `p This is #[em emphasized] text.`


### Inline HTML ###

TODO!


Text nodes
----------

Pure text content can be specified using the `|` prefix. The text that follows will be treated as contents of the parent node. The `&`, `=` and `!=` suffixes are supported and behave the same as for *tags*.

Example:

	p This is a long
		| paragraph that is
		| split across multiple
		| lines.


Comments
--------

Comments are prefixed with `//`. The line itself, as well as any nested lines following it will be treated as contents of the comment. Adding a single dash (`//-`) will force the comment contents to not appear in the generated result. Otherwise, if the output format supports it, the contents will appear as a comment in the output.

	// Looking for a HTML job? jobs.localhost
	//- Password = 123456

Generates

	<!-- Looking for a HTML job? jobs.localhost -->


Embedded D code
---------------

### Statements

D statements can be inserted by prefixing them with a single dash (`-`). A scope will be created around any nested contents, so that it is possible to use control statements.

Example:
	
	- int i = 1;
	- i++;
	- if (i > 1)
		p OK
	- else
		p No!

Will output `<p>OK</p>`

Function declarations are also supported using their natural D syntax:

	- void foo(int i)
		- p= i
	
	- foo(0);
	- foo(1);

Will output `<p>0</p><p>1</p>`


### Text interpolations

D expressions can be embedded within text contents using the *text interpolation* syntax. The expression will first be converted to a string using the conversion rules of [std.conv](http://dlang.org/phobos/std_conv.html), and is then either properly escaped for the output format, or inserted verbatim.

The syntax for escaped processing is `#{...}` and should always be used, unless the expression is expected to yield a string that has the same format as the output (e.g. HTML). For verbatim output, use `!{...}`.

Any `#` or `!` that is not followed by a `{` (or `[` in case of inline tags) will be interpreted as a simple character. If these characters are supposed to be interpreted as characters despite being followed by a brace, the backslash character can be used to escape them.

Example:

    p This text #{"cont"~"ains"} dynamically generated !{"<i>"~"text"~"</i>"}.
    p It uses the syntax \#{...} or \!{...}.

Outputs:

    <p>This text contains dynamically generated <i>text</i></p>
    <p>It uses the syntax #{...} or !{...}.</p>


### Interpolations in attributes

These work almost the same as normal text interpolations, except that they obey different escaping rules that depend on the output format.

Example:

	- foreach (i; 0 .. 3)
		p(class='text#{i % 2 ? "even" : "odd"}') #{i+1}

Outputs:

	<p class="odd">1</p>
	<p class="even">2</p>
	<p class="odd">3</p>


Filters
-------

`:filter1 :filter2 text`

**TODO!**


Includes
--------

With includes it is possible to embed one template in another. The included template gets pasted at the position of the include-keyword. The indentation of the include-portion will propagate to the included template.

Command: `include file(.ext)`

Example:

	// main.dt
	doctype html
	html
		head
			title includeExample
		body
			h2  the following content is not in this file ...
			include otherfile


	// otherfile.dt	
	h3 ... But In the other file and this
	include yetanotherfile


	// yetanotherfile.dt
	h4 in yet anotherfile

Outputs:

	<!DOCTYPE html>
	<html>
		<head>
			<title>includeExample</title>
		</head>
		<body>
			<h2> the following content is not in this file ... </h2>
			<h3> ... But In the other file and this </h3>
			<h4> in yet another file </h4>
		</body>
	</html>

In the case of error `Missing include input file` check [templates placement](#templates-placement).

Blocks and Extensions
---------------------

`extend file(.ext)`

**TODO!**


HTML-specific Features
----------------------

### Doctype Specifications

`doctype ...`

Legacy syntax: `!!! ...` will be transformed to `doctype ...`

**TODO!**

Templates placement
-------------------

Diet looks for templates according to the list of directories specified in the parameter stringImportPaths of dub config file (see dub documentation for [json](https://code.dlang.org/package-format?lang=json#build-settings) or [sdl](https://code.dlang.org/package-format?lang=sdl#build-settings) format). Default value is `views/`.
This applies to a method call `compileHTMLDietFile` and directives in the file being processed. `compileHTMLDietString` at the moment can not find include files by yourself, it is necessary to take additional steps (see answer [here](http://forum.rejectedsoftware.com/groups/rejectedsoftware.vibed/post/41058)).

Grammar
-------

**TODO!**
