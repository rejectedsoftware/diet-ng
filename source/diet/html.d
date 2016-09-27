/** HTML output generator implementation.
*/
module diet.html;

import diet.defs;
import diet.dom;
import diet.internal.html;
import diet.internal.string;
import diet.input;
import diet.parser;
import diet.traits;


/** Compiles a Diet template file that is available as a string import.

	The final HTML will be written to the given `_diet_output` output range.

	Params:
		filename = Name of the main Diet template file.
		ALIASES = A list of variables to make available inside of the template,
			as well as traits structs annotated with the `@dietTraits`
			attribute.
		dst = The output range to write the generated HTML to.

	Traits:
		In addition to the default Diet traits, adding an enum field
		`htmlOutputStyle` of type `HTMLOutputStyle` to a traits
		struct can be used to control the style of the generated
		HTML.

	See_Also: `compileHTMLDietString`, `compileHTMLDietStrings`
*/
template compileHTMLDietFile(string filename, ALIASES...)
{
	import std.conv : to;	
	enum _diet_files = collectFiles!filename;

	version (DietUseCache) enum _diet_use_cache = true;
	else enum _diet_use_cache = false;


	ulong computeTemplateHash()
	{
		ulong ret = 0;
		void hash(string s)
		{
			foreach (char c; s) {
				ret *= 9198984547192449281;
				ret += c * 7576889555963512219;
			}
		}
		foreach (ref f; _diet_files) {
			hash(f.name);
			hash(f.contents);
		}
		return ret;
	}

	enum _diet_hash = computeTemplateHash();
	enum _diet_cache_file_name = "_cached_"~filename~"_"~_diet_hash.to!string~".d";

	static if (_diet_use_cache && is(typeof(import(_diet_cache_file_name)))) {
		pragma(msg, "Using cached Diet HTML template "~filename~"...");
		enum _dietParser = import(_diet_cache_file_name);
	} else {
		alias TRAITS = DietTraits!ALIASES;
		pragma(msg, "Compiling Diet HTML template "~filename~"...");
		private Document _diet_nodes() { return applyTraits!TRAITS(parseDiet!(translate!TRAITS)(_diet_files)); }
		enum _dietParser = getHTMLMixin(_diet_nodes(), dietOutputRangeName, getHTMLOutputStyle!TRAITS);

		static if (_diet_use_cache) {
			shared static this()
			{
				import std.file : exists, write;
				if (!exists("views/"~_diet_cache_file_name))
					write("views/"~_diet_cache_file_name, _dietParser);
			}
		}
	}

	// uses the correct range name and removes 'dst' from the scope
	private void exec(R)(ref R _diet_output)
	{
		mixin(localAliasesMixin!(0, ALIASES));
		//pragma(msg, getHTMLMixin(nodes));
		mixin(_dietParser);
	}

	void compileHTMLDietFile(R)(ref R dst)
	{
		exec(dst);
	}
}

/** Compiles a Diet template given as a string.

	The final HTML will be written to the given `_diet_output` output range.

	Params:
		contents = The contents of the Diet template
		ALIASES = A list of variables to make available inside of the template,
			as well as traits structs annotated with the `@dietTraits`
			attribute.
		dst = The output range to write the generated HTML to.

	See_Also: `compileHTMLDietString`, `compileHTMLDietStrings`
*/
template compileHTMLDietString(string contents, ALIASES...)
{
	void compileHTMLDietString(R)(ref R dst)
	{
		compileHTMLDietStrings!(Group!(contents, "diet-string"), ALIASES)(dst);
	}
}

/** Compiles a set of Diet template files.

	The final HTML will be written to the given `_diet_output` output range.

	Params:
		FILES_GROUP = A `diet.input.Group` containing an alternating list of
			file names and file contents.
		ALIASES = A list of variables to make available inside of the template,
			as well as traits structs annotated with the `@dietTraits`
			attribute.
		dst = The output range to write the generated HTML to.

	See_Also: `compileHTMLDietString`, `compileHTMLDietStrings`
*/
template compileHTMLDietStrings(alias FILES_GROUP, ALIASES...)
{
	alias TRAITS = DietTraits!ALIASES;
	private static Document _diet_nodes() { return applyTraits!TRAITS(parseDiet!(translate!TRAITS)(filesFromGroup!FILES_GROUP)); }

	// uses the correct range name and removes 'dst' from the scope
	private void exec(R)(ref R _diet_output)
	{
		mixin(localAliasesMixin!(0, ALIASES));
		//pragma(msg, getHTMLMixin(_diet_nodes()));
		mixin(getHTMLMixin(_diet_nodes(), dietOutputRangeName, getHTMLOutputStyle!TRAITS));
	}

	void compileHTMLDietStrings(R)(ref R dst)
	{
		exec(dst);
	}
}

/** Returns a mixin string that generates HTML for the given DOM tree.

	Params:
		nodes = The root nodes of the DOM tree
		range_name = Optional custom name to use for the output range, defaults
			to `_diet_output`.

	Returns:
		A string of D statements suitable to be mixed in inside of a function.
*/
string getHTMLMixin(in Document doc, string range_name = dietOutputRangeName, HTMLOutputStyle style = HTMLOutputStyle.compact)
{
	CTX ctx;
	ctx.pretty = style == HTMLOutputStyle.pretty;
	ctx.rangeName = range_name;
	string ret = "import diet.internal.html : htmlEscape, htmlAttribEscape;\n";
	ret ~= "import std.format : formattedWrite;\n";
	foreach (i, n; doc.nodes)
		ret ~= ctx.getHTMLMixin(n, i == 0);
	ret ~= ctx.flushRawText();
	return ret;
}

unittest {
	import diet.parser;
	void test(string src)(string expected) {
		import std.array : appender;
		static const n = parseDiet(src);
		auto _diet_output = appender!string();
		//pragma(msg, getHTMLMixin(n));
		mixin(getHTMLMixin(n));
		assert(_diet_output.data == expected, _diet_output.data);
	}

	test!"doctype html\nfoo(test=true)"("<!DOCTYPE html><foo test></foo>");
	test!"doctype X\nfoo(test=true)"("<!DOCTYPE X><foo test=\"test\"></foo>");
	test!"foo(test=2+3)"("<foo test=\"5\"></foo>");
	test!"foo(test='#{2+3}')"("<foo test=\"5\"></foo>");
	test!"foo #{2+3}"("<foo>5</foo>");
	test!"foo= 2+3"("<foo>5</foo>");
	test!"- int x = 3;\nfoo=x"("<foo>3</foo>");
	test!"- foreach (i; 0 .. 2)\n\tfoo"("<foo></foo><foo></foo>");
	test!"div(*ngFor=\"\\#item of list\")"(
		"<div *ngFor=\"#item of list\"></div>"
	);
	test!".foo"("<div class=\"foo\"></div>");
	test!"#foo"("<div id=\"foo\"></div>");
}


/** Determines how the generated HTML gets styled.

	To use this, put an enum field named `htmlOutputStyle` into a diet traits
	struct and pass that to the render function.

	The default output style is `compact`.
*/
enum HTMLOutputStyle {
	compact, /// Outputs no extraneous whitespace (including line breaks) around HTML tags
	pretty, /// Inserts line breaks and indents lines according to their nesting level in the HTML structure
}

///
unittest {
	@dietTraits
	struct Traits {
		enum htmlOutputStyle = HTMLOutputStyle.pretty;
	}

	import std.array : appender;
	auto dst = appender!string();
	dst.compileHTMLDietString!("html\n\tbody\n\t\tp Hello", Traits);
	import std.conv : to;
	assert(dst.data == "<html>\n\t<body>\n\t\t<p>Hello</p>\n\t</body>\n</html>", [dst.data].to!string);
}

private @property template getHTMLOutputStyle(TRAITS...)
{
	static if (TRAITS.length) {
		static if (is(typeof(TRAITS[0].htmlOutputStyle)))
			enum getHTMLOutputStyle = TRAITS[0].htmlOutputStyle;
		else enum getHTMLOutputStyle = getHTMLOutputStyle!(TRAITS[1 .. $]);
	} else enum getHTMLOutputStyle = HTMLOutputStyle.compact;
}

private string getHTMLMixin(ref CTX ctx, in Node node, bool first)
{
	switch (node.name) {
		default: return ctx.getElementMixin(node);
		case "doctype": return ctx.getDoctypeMixin(node);
		case Node.SpecialName.code: return ctx.getCodeMixin(node);
		case Node.SpecialName.comment: return ctx.getCommentMixin(node);
		case Node.SpecialName.hidden: return null;
		case Node.SpecialName.text:
			string ret;
			if (!first)
				ret ~= ctx.rawText(node.loc, "\n");
			foreach (i, c; node.contents)
				ret ~= ctx.getNodeContentsMixin(c, i == 0);
			return ret;
	}
}

private string getElementMixin(ref CTX ctx, in Node node)
{
	import std.algorithm : countUntil;

	bool need_newline = ctx.needPrettyNewline(node.contents);

	// write tag name
	string tagname = node.name.length ? node.name : "div";
	string ret;
	if (need_newline) ctx.prettyNewLine();
	ret ~= ctx.rawText(node.loc, "<"~tagname);

	bool had_class = false;

	// write attributes
	foreach (ai, att_; node.attributes) {
		auto att = att_.dup; // this sucks...

		// merge multiple class attributes into one
		if (att.name == "class") {
			if (had_class) continue;
			had_class = true;
			foreach (ca; node.attributes[ai+1 .. $]) {
				if (ca.name != "class") continue;
				if (!ca.contents.length || (ca.isText && !ca.expectText.length)) continue;
				att.addText(" ");
				att.addContents(ca.contents);
			}
		}

		bool is_expr = att.contents.length == 1 && att.contents[0].kind == AttributeContent.Kind.interpolation;

		if (is_expr) {
			auto expr = att.contents[0].value;

			if (expr == "true") {
				if (ctx.isHTML5) ret ~= ctx.rawText(node.loc, " "~att.name);
				else ret ~= ctx.rawText(node.loc, " "~att.name~"=\""~att.name~"\"");
				continue;
			}

			ret ~= ctx.statement(node.loc, q{static if (is(typeof(%s) == bool)) }~'{', expr);
			if (ctx.isHTML5) ret ~= ctx.statement(node.loc, q{if (%s) %s.put(" %s");}, expr, ctx.rangeName, att.name);
			else ret ~= ctx.statement(node.loc, q{if (%s) %s.put(" %s=\"%s\"");}, expr, ctx.rangeName, att.name, att.name);
			ret ~= ctx.statement(node.loc, "} else "~q{static if (is(typeof(%s) : const(char)[])) }~"{{", expr);
			ret ~= ctx.statement(node.loc, q{  auto val = %s;}, expr);
			ret ~= ctx.statement(node.loc, q{  if (val !is null) }~'{');
			ret ~= ctx.rawText(node.loc, " "~att.name~"=\"");
			ret ~= ctx.statement(node.loc, q{    %s.filterHTMLAttribEscape(val);}, ctx.rangeName);
			ret ~= ctx.rawText(node.loc, "\"");
			ret ~= ctx.statement(node.loc, "  }");
			ret ~= ctx.statement(node.loc, "}} else {");
		}

		ret ~= ctx.rawText(node.loc, " "~att.name ~ "=\"");

		foreach (i, v; att.contents) {
			final switch (v.kind) with (AttributeContent.Kind) {
				case text:
					ret ~= ctx.rawText(node.loc, htmlAttribEscape(v.value));
					break;
				case interpolation, rawInterpolation:
					ret ~= ctx.statement(node.loc, q{%s.htmlAttribEscape(%s);}, ctx.rangeName, v.value);
					break;
			}
		}

		ret ~= ctx.rawText(node.loc, "\"");

		if (is_expr) ret ~= ctx.statement(node.loc, "}");
	}

	// determine if we need a closing tag or have a singular tag
	switch (node.name) {
		default: break;
		case "area", "base", "basefont", "br", "col", "embed", "frame",	"hr", "img", "input",
				"keygen", "link", "meta", "param", "source", "track", "wbr":
			enforcep(!node.contents.length, "Singular HTML element '"~node.name~"' may not have contents.", node.loc);
			ret ~= ctx.rawText(node.loc, "/>");
			enforcep(node.contents.length == 0, "Singular tag <"~node.name~"> may not have contents.", node.loc);
			return ret;
	}

	ret ~= ctx.rawText(node.loc, ">");

	// write contents
	if (need_newline) {
		ctx.depth++;
		ctx.prettyNewLine();
	}
	
	foreach (i, c; node.contents)
		ret ~= ctx.getNodeContentsMixin(c, i == 0);
	
	if (need_newline) {
		ctx.depth--;
		ctx.prettyNewLine();
	}

	// write end tag
	ret ~= ctx.rawText(node.loc, "</"~tagname~">");

	if (need_newline) ctx.prettyNewLine();

	return ret;
}

private string getNodeContentsMixin(ref CTX ctx, in NodeContent c, bool first)
{
	final switch (c.kind) with (NodeContent.Kind) {
		case node:
			return getHTMLMixin(ctx, c.node, first);
		case text:
			return ctx.rawText(c.loc, c.value);
		case interpolation:
			return ctx.textStatement(c.loc, q{%s.htmlEscape(%s);}, ctx.rangeName, c.value);
		case rawInterpolation:
			return ctx.textStatement(c.loc, q{() @trusted { return (&%s); } ().formattedWrite("%%s", %s);}, ctx.rangeName, c.value);
	}
}

private string getDoctypeMixin(ref CTX ctx, in Node node)
{
	import diet.internal.string;

	if (node.name == "!!!")
		ctx.statement(node.loc, q{pragma(msg, "Use of '!!!' is deprecated. Use 'doctype' instead.");});

	enforcep(node.contents.length == 1 && node.contents[0].kind == NodeContent.Kind.text,
		"Only doctype specifiers allowed as content for doctype nodes.", node.loc);

	auto args = ctstrip(node.contents[0].value);

	ctx.isHTML5 = false;

	string doctype_str = "!DOCTYPE html";
	switch (args) {
		case "5":
		case "":
		case "html":
			ctx.isHTML5 = true;
			break;
		case "xml":
			doctype_str = `?xml version="1.0" encoding="utf-8" ?`;
			break;
		case "transitional":
			doctype_str = `!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" `
				~ `"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd`;
			break;
		case "strict":
			doctype_str = `!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" `
				~ `"http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd"`;
			break;
		case "frameset":
			doctype_str = `!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Frameset//EN" `
				~ `"http://www.w3.org/TR/xhtml1/DTD/xhtml1-frameset.dtd"`;
			break;
		case "1.1":
			doctype_str = `!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN" `
				~ `"http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd"`;
			break;
		case "basic":
			doctype_str = `!DOCTYPE html PUBLIC "-//W3C//DTD XHTML Basic 1.1//EN" `
				~ `"http://www.w3.org/TR/xhtml-basic/xhtml-basic11.dtd"`;
			break;
		case "mobile":
			doctype_str = `!DOCTYPE html PUBLIC "-//WAPFORUM//DTD XHTML Mobile 1.2//EN" `
				~ `"http://www.openmobilealliance.org/tech/DTD/xhtml-mobile12.dtd"`;
			break;
		default:
			doctype_str = "!DOCTYPE " ~ args;
		break;
	}

	return ctx.rawText(node.loc, "<"~dstringEscape(doctype_str)~">");
}

private string getCodeMixin(ref CTX ctx, in ref Node node)
{
	enforcep(node.attributes.length == 0, "Code lines may not have attributes.", node.loc);
	enforcep(node.attribs == NodeAttribs.none, "Code lines may not specify translation or text block suffixes.", node.loc);
	if (node.contents.length == 0) return null;

	string ret;
	bool got_code = false;
	foreach (i, c; node.contents) {
		if (i == 0 && c.kind == NodeContent.Kind.text) {
			ret ~= ctx.statement(node.loc, "%s {", c.value);
			got_code = true;
		} else {
			assert(c.kind == NodeContent.Kind.node);
			ret ~= ctx.getHTMLMixin(c.node, i == 0 || (got_code && i == 1));
		}
	}
	ret ~= ctx.statement(node.loc, "}");
	return ret;
}

private string getCommentMixin(ref CTX ctx, in ref Node node)
{
	string ret = ctx.rawText(node.loc, "<!--");
	ctx.depth++;
	foreach (i, c; node.contents)
		ret ~= ctx.getNodeContentsMixin(c, i == 0);
	ctx.depth--;
	ret ~= ctx.rawText(node.loc, "-->");
	return ret;
}

private struct CTX {
	bool isHTML5;
	bool pretty;
	int depth = 0;
	string rangeName;
	bool inRawText;
	bool newlinePending, anyText;

	pure string statement(ARGS...)(Location loc, string fmt, ARGS args)
	{
		import std.string : format;
		string ret = flushRawText();
		ret ~= ("#line %s \"%s\"\n"~fmt~"\n").format(loc.line+1, loc.file, args);
		return ret;
	}

	pure string textStatement(ARGS...)(Location loc, string fmt, ARGS args)
	{
		string ret;
		if (pretty && newlinePending) ret ~= rawText(loc, null);
		ret ~= statement(loc, fmt, args);
		return ret;
	}

	pure string rawText(ARGS...)(Location loc, string text)
	{
		string ret;
		if (!this.inRawText) {
			ret = this.rangeName ~ ".put(\"";
			this.inRawText = true;
		}
		ret ~= outputPendingNewline();
		ret ~= dstringEscape(text);
		anyText = true;
		return ret;
	}

	pure string flushRawText()
	{
		if (this.inRawText) {
			this.inRawText = false;
			return "\");\n";
		}
		return null;
	}

	void prettyNewLine() { newlinePending = true; }

	bool needPrettyNewline(in NodeContent[] contents) {
		import std.algorithm.searching : any;
		return pretty && contents.any!(c => c.kind == NodeContent.Kind.node);
	}

	private pure string outputPendingNewline()
	{
		if (pretty && newlinePending) {
			import std.array : replicate;
			newlinePending = false;
			return anyText ? "\n"~"\t".replicate(depth) : null;
		}
		return null;
	}
}

unittest {
	static string compile(string diet, ALIASES...)() {
		import std.array : appender;
		import std.string : strip;
		auto dst = appender!string;
		compileHTMLDietString!(diet, ALIASES)(dst);
		return strip(cast(string)(dst.data));
	}

	assert(compile!(`!!! 5`) == `<!DOCTYPE html>`, `_`~compile!(`!!! 5`)~`_`);
	assert(compile!(`!!! html`) == `<!DOCTYPE html>`);
	assert(compile!(`doctype html`) == `<!DOCTYPE html>`);
	assert(compile!(`p= 5`) == `<p>5</p>`);
	assert(compile!(`script= 5`) == `<script>5</script>`);
	assert(compile!(`style= 5`) == `<style>5</style>`);
	//assert(compile!(`include #{"p Hello"}`) == "<p>Hello</p>");
	assert(compile!(`<p>Hello</p>`) == "<p>Hello</p>");
	assert(compile!(`// I show up`) == "<!-- I show up-->");
	assert(compile!(`//-I don't show up`) == "");
	assert(compile!(`//- I don't show up`) == "");

	// issue 372
	assert(compile!(`div(class="")`) == `<div></div>`);
	assert(compile!(`div.foo(class="")`) == `<div class="foo"></div>`);
	assert(compile!(`div.foo(class="bar")`) == `<div class="foo bar"></div>`);
	assert(compile!(`div(class="foo")`) == `<div class="foo"></div>`);
	assert(compile!(`div#foo(class='')`) == `<div id="foo"></div>`);

	// issue 520
	assert(compile!("- auto cond = true;\ndiv(someattr=cond ? \"foo\" : null)") == "<div someattr=\"foo\"></div>");
	assert(compile!("- auto cond = false;\ndiv(someattr=cond ? \"foo\" : null)") == "<div></div>");
	assert(compile!("- auto cond = false;\ndiv(someattr=cond ? true : false)") == "<div></div>");
	assert(compile!("- auto cond = true;\ndiv(someattr=cond ? true : false)") == "<div someattr=\"someattr\"></div>");
	assert(compile!("doctype html\n- auto cond = true;\ndiv(someattr=cond ? true : false)")
		== "<!DOCTYPE html><div someattr></div>");
	assert(compile!("doctype html\n- auto cond = false;\ndiv(someattr=cond ? true : false)")
		== "<!DOCTYPE html><div></div>");

	// issue 510
	assert(compile!("pre.test\n\tfoo") == "<pre class=\"test\"><foo></foo></pre>");
	assert(compile!("pre.test.\n\tfoo") == "<pre class=\"test\">foo</pre>");
	assert(compile!("pre.test. foo") == "<pre class=\"test\"></pre>");
	assert(compile!("pre().\n\tfoo") == "<pre>foo</pre>");
	assert(compile!("pre#foo.test(data-img=\"sth\",class=\"meh\"). something\n\tmeh") ==
		   "<pre id=\"foo\" class=\"test meh\" data-img=\"sth\">meh</pre>");

	assert(compile!("input(autofocus)").length);

	assert(compile!("- auto s = \"\";\ninput(type=\"text\",value=\"&\\\"#{s}\")")
			== `<input type="text" value="&amp;&quot;"/>`);
	assert(compile!("- auto param = \"t=1&u=1\";\na(href=\"/?#{param}&v=1\") foo")
			== `<a href="/?t=1&amp;u=1&amp;v=1">foo</a>`);

	// issue #1021
	assert(compile!("html( lang=\"en\" )")
		== "<html lang=\"en\"></html>");

	// issue #1033
	assert(compile!("input(placeholder=')')")
		== "<input placeholder=\")\"/>");
	assert(compile!("input(placeholder='(')")
		== "<input placeholder=\"(\"/>");
}

unittest { // blocks and extensions
	static string compilePair(string extension, string base, ALIASES...)() {
		import std.array : appender;
		import std.string : strip;
		auto dst = appender!string;
		compileHTMLDietStrings!(Group!(extension, "extension.dt", base, "base.dt"), ALIASES)(dst);
		return strip(dst.data);
	}

	assert(compilePair!("extends base\nblock test\n\tp Hello", "body\n\tblock test")
		 == "<body><p>Hello</p></body>");
	assert(compilePair!("extends base\nblock test\n\tp Hello", "body\n\tblock test\n\t\tp Default")
		 == "<body><p>Hello</p></body>");
	assert(compilePair!("extends base", "body\n\tblock test\n\t\tp Default")
		 == "<body><p>Default</p></body>");
	assert(compilePair!("extends base\nprepend test\n\tp Hello", "body\n\tblock test\n\t\tp Default")
		 == "<body><p>Hello</p><p>Default</p></body>");
}

/*@nogc*/ @safe unittest { // NOTE: formattedWrite is not @nogc
	static struct R {
		@nogc @safe nothrow:
		void put(in char[]) {}
		void put(char) {}
		void put(dchar) {}
	}

	R r;
	r.compileHTMLDietString!(
`doctype html
html
	- foreach (i; 0 .. 10)
		title= i
	title t #{12} !{13}
`);
}

unittest { // issue 4 - nested text in code
	static string compile(string diet, ALIASES...)() {
		import std.array : appender;
		import std.string : strip;
		auto dst = appender!string;
		compileHTMLDietString!(diet, ALIASES)(dst);
		return strip(cast(string)(dst.data));
	}
	assert(compile!"- if (true)\n\t| int bar;" == "int bar;", compile!"- if (true)\n\t| int bar;");
}

unittest { // class instance variables
	import std.array : appender;
	import std.string : strip;

	static class C {
		int x = 42;

		string test()
		{
			auto dst = appender!string;
			dst.compileHTMLDietString!("| #{x}", x);
			return dst.data;
		}
	}

	auto c = new C;
	assert(c.test().strip == "42");
}

unittest { // raw interpolation for non-copyable range
	struct R { @disable this(this); void put(dchar) {} void put(in char[]) {} }
	R r;
	r.compileHTMLDietString!("a !{2}");
}

unittest {
	assert(utCompile!(".foo(class=true?\"bar\":\"baz\")") == "<div class=\"foo bar\"></div>", utCompile!".foo(class=true?\"bar\":\"baz\")");
}

version (unittest) {
	private string utCompile(string diet, ALIASES...)() {
		import std.array : appender;
		import std.string : strip;
		auto dst = appender!string;
		compileHTMLDietString!(diet, ALIASES)(dst);
		return strip(cast(string)(dst.data));
	}
}
