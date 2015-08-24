module diet.html;

import diet.dom;
import diet.exception;
import diet.internal.html;
import diet.internal.string;
import diet.input;


enum defaultOutputRangeName = "_output_";

template Group(A...) {
	import std.typetuple;
	alias expand = TypeTuple!A;
}

template compileHTMLDietString(string contents, ALIASES...)
{
	void compileHTMLDietString(R)(ref R dst)
	{
		compileHTMLDietStrings!(Group!(contents, "diet-string"), ALIASES)(dst);
	}
}

template compileHTMLDietStrings(alias FILES_GROUP, ALIASES...)
{
	void compileHTMLDietStrings(R)(ref R _output_)
	{
		import diet.parser;
		enum nodes = parseDiet(filesFromGroup!FILES_GROUP);
		//pragma(msg, getHTMLMixin(nodes));
		mixin(getHTMLMixin(nodes));
	}
}

string getHTMLMixin(in Node[] nodes, string range_name = defaultOutputRangeName)
{
	CTX ctx;
	ctx.rangeName = range_name;
	string ret = "import std.conv : to;\n";
	foreach (n; nodes)
		ret ~= ctx.getHTMLMixin(n);
	return ret;
}

unittest {
	import diet.parser;
	void test(string src)(string expected) {
		import std.array : appender;
		static const n = parseDiet(src);
		auto _output_ = appender!string();
		//pragma(msg, getHTMLMixin(n));
		mixin(getHTMLMixin(n));
		assert(_output_.data == expected, _output_.data);
	}

	test!"doctype html\nfoo(test=true)"("<!DOCTYPE html><foo test></foo>");
	test!"doctype X\nfoo(test=true)"("<!DOCTYPE X><foo test=\"test\"></foo>");
	test!"foo(test=2+3)"("<foo test=\"5\"></foo>");
	test!"foo(test='#{2+3}')"("<foo test=\"5\"></foo>");
	test!"foo #{2+3}"("<foo>5</foo>");
	test!"foo= 2+3"("<foo>5</foo>");
	test!"- int x = 3;\nfoo=x"("<foo>3</foo>");
	test!"- foreach (i; 0 .. 2)\n\tfoo"("<foo></foo><foo></foo>");
}

private string getHTMLMixin(ref CTX ctx, in Node node)
{
	switch (node.name) {
		default: return ctx.getElementMixin(node);
		case "doctype": return ctx.getDoctypeMixin(node);
		case "-": return ctx.getCodeMixin(node);
		case "//": return ctx.getCommentMixin(node);
		case "//-": return null;
		case "|":
			string ret;
			foreach (c; node.contents)
				ret ~= ctx.getNodeContentsMixin(c);
			return ret;

	}
}

private string getElementMixin(ref CTX ctx, in Node node)
{
	import std.algorithm : countUntil;

	// write tag name
	string ret = statement(node.loc, q{%s.put("<%s");}, ctx.rangeName, node.name);

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
				att.addText(" ");
				att.addContents(ca.values);
			}
		}

		bool is_expr = att.values.length == 1 && att.values[0].kind == AttributeContent.Kind.interpolation;

		if (is_expr) {
			auto expr = att.values[0].value;

			if (expr == "true") {
				if (ctx.isHTML5) ret ~= statement(node.loc, q{%s.put(" %s");}, ctx.rangeName, att.name);
				else ret ~= statement(node.loc, q{%s.put(" %s=\"%s\"");}, ctx.rangeName, att.name, att.name);
				continue;
			}

			ret ~= statement(node.loc, q{static if (is(typeof(%s) == bool)) }~'{', expr);
			if (ctx.isHTML5) ret ~= statement(node.loc, q{if (%s) %s.put(" %s");}, expr, ctx.rangeName, att.name);
			else ret ~= statement(node.loc, q{if (%s) %s.put(" %s=\"%s\"");}, expr, ctx.rangeName, att.name, att.name);
			ret ~= statement(node.loc, "} else "~q{static if (is(typeof(%s) : const(char)[])) }~'{', expr);
			ret ~= statement(node.loc, q{  auto val = %s;}, expr);
			ret ~= statement(node.loc, q{  if (val !is null) }~'{');
			ret ~= statement(node.loc, q{    %s.put(" %s=\"");}, ctx.rangeName, att.name);
			ret ~= statement(node.loc, q{    %s.filterHTMLAttribEscape(val);}, ctx.rangeName);
			ret ~= rawText(node.loc, ctx.rangeName, "\"");
			ret ~= statement(node.loc, "  }");
			ret ~= statement(node.loc, "} else {");
		}

		ret ~= statement(node.loc, q{%s.put(" %s=\"");}, ctx.rangeName, att.name);

		foreach (i, v; att.values) {
			final switch (v.kind) with (AttributeContent.Kind) {
				case text:
					ret ~= rawText(node.loc, ctx.rangeName, htmlAttribEscape(v.value));
					break;
				case interpolation, rawInterpolation:
					ret ~= statement(node.loc, q{%s.filterHTMLAttribEscape((%s).to!string);}, ctx.rangeName, v.value);
					break;
			}
		}

		ret ~= rawText(node.loc, ctx.rangeName, "\"");

		if (is_expr) ret ~= statement(node.loc, "}");
	}

	// determine if we need a closing tag or have a singular tag
	switch (node.name) {
		default: break;
		case "area", "base", "basefont", "br", "col", "embed", "frame",	"hr", "img", "input",
				"keygen", "link", "meta", "param", "source", "track", "wbr":
			enforcep(!node.contents.length, "Singular HTML element '"~node.name~"' may not have contents.", node.loc);
			ret ~= rawText(node.loc, ctx.rangeName, "/>");
			enforcep(node.contents.length == 0, "Singular tag <"~node.name~"> may not have contents.", node.loc);
			return ret;
	}

	ret ~= rawText(node.loc, ctx.rangeName, ">");

	// write contents
	ctx.depth++;
	foreach (c; node.contents)
		ret ~= ctx.getNodeContentsMixin(c);
	ctx.depth--;

	// write end tag
	ret ~= statement(node.loc, q{%s.put("</%s>");}, ctx.rangeName, node.name);

	return ret;
}

private string getNodeContentsMixin(ref CTX ctx, in NodeContent c)
{
	// TODO: translation!
	final switch (c.kind) with (NodeContent.Kind) {
		case node:
			string ret;
			ret ~= ctx.prettyNewLine(c.loc);
			ret ~= getElementMixin(ctx, c.node);
			ret ~= ctx.prettyNewLine(c.loc);
			return ret;
		case text:
			return rawText(c.loc, ctx.rangeName, c.value);
		case interpolation:
			return statement(c.loc, q{%s.filterHTMLEscape((%s).to!string);}, ctx.rangeName, c.value);
		case rawInterpolation:
			return statement(c.loc, q{%s.put((%s).to!string);}, ctx.rangeName, c.value);
	}
}

private string getDoctypeMixin(ref CTX ctx, in Node node)
{
	import diet.internal.string;

	if (node.name == "!!!")
		statement(node.loc, q{pragma(msg, "Use of '!!!' is deprecated. Use 'doctype' instead.");});

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

	return statement(node.loc, q{%s.put("<%s>");}, ctx.rangeName, dstringEscape(doctype_str));
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
			ret ~= statement(node.loc, "%s {", c.value);
			got_code = true;
		} else {
			ret ~= ctx.getNodeContentsMixin(c);
		}
	}
	ret ~= statement(node.loc, "}");
	return ret;
}

private string getCommentMixin(ref CTX ctx, in ref Node node)
{
	string ret = rawText(node.loc, ctx.rangeName, "<!--");
	foreach (c; node.contents)
		ret ~= ctx.getNodeContentsMixin(c);
	ret ~= rawText(node.loc, ctx.rangeName, "-->");
	return ret;
}

private pure string statement(ARGS...)(Location loc, string fmt, ARGS args)
{
	import std.string : format;
	return ("#line %s \"%s\"\n"~fmt~"\n").format(loc.line+1, loc.file, args);
}

private pure string rawText(ARGS...)(Location loc, string range_name, string text)
{
	return statement(loc, q{%s.put("%s");}, range_name, dstringEscape(text));
}

private struct CTX {
	bool isHTML5;
	bool pretty = false;
	int depth = 0;
	string rangeName;

	string prettyNewLine(in ref Location loc) {
		import std.array : replicate;
		if (pretty) return rawText(loc, rangeName, "\n"~"\t".replicate(depth));
		else return null;
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
		 == "<body>\n\t<p>Hello</p>\n</body>");
	assert(compilePair!("extends base\nblock test\n\tp Hello", "body\n\tblock test\n\t\tp Default")
		 == "<body>\n\t<p>Hello</p>\n</body>", compilePair!("extends base\nblock test\n\tp Hello", "body\n\tblock test\n\t\tp Default"));
	assert(compilePair!("extends base", "body\n\tblock test\n\t\tp Default")
		 == "<body>\n\t<p>Default</p>\n</body>");
	assert(compilePair!("extends base\nprepend test\n\tp Hello", "body\n\tblock test\n\t\tp Default")
		 == "<body>\n\t<p>Hello</p>\n\t<p>Default</p>\n</body>");
}
