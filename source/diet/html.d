module diet.html;

import diet.dom;
import diet.exception;
import diet.internal.string;


string htmlAttribEscape(string s) { return s; }
void writeHTMLEscaped(R)(ref R dst, string s) { dst.put(s); }
void writeHTMLAttribEscaped(R)(ref R dst, string s) { dst.put(s); }


enum defaultOutputRangeName = "__output";

string getHTMLMixin(in Node[] nodes, string range_name = defaultOutputRangeName)
{
	assert(nodes.length > 0, "Cannot render empty Diet file.");
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
		auto __output = appender!string();
		//pragma(msg, getHTMLMixin(n));
		mixin(getHTMLMixin(n));
		assert(__output.data == expected, __output.data);
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
		case "doctype", "!!!": return ctx.getDoctypeMixin(node);
		case "-": return ctx.getCodeMixin(node);
		case "//": // TODO!
		case "//-": return null;
	}
}

private string getElementMixin(ref CTX ctx, in Node node)
{
	// write tag name
	string ret = statement(node.loc, q{%s.put("<%s");}, ctx.rangeName, node.name);

	// write attributes
	foreach (att; node.attributes) {
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
			ret ~= statement(node.loc, "} else {");
		}

		ret ~= statement(node.loc, q{%s.put(" %s=\"");}, ctx.rangeName, att.name);
		foreach (i, v; att.values) {
			final switch (v.kind) with (AttributeContent.Kind) {
				case text:
					ret ~= rawText(node.loc, ctx.rangeName, htmlAttribEscape(v.value));
					break;
				case interpolation, rawInterpolation:
					ret ~= statement(node.loc, q{%s.writeHTMLAttribEscaped((%s).to!string);}, ctx.rangeName, v.value);
					break;
			}
		}
		ret ~= rawText(node.loc, ctx.rangeName, "\"");

		if (is_expr) ret ~= statement(node.loc, "}");
	}

	// determine if we need a closing tag or have a singular tag
	switch (node.name) {
		case "area", "base", "basefont", "br", "col", "embed", "frame",	"hr", "img", "input",
				"keygen", "link", "meta", "param", "source", "track", "wbr":
			enforcep(!node.contents.length, "Singular HTML element '"~node.name~"' may not have contents.", node.loc);
			ret ~= rawText(node.loc, ctx.rangeName, "/>");
		default:
			ret ~= rawText(node.loc, ctx.rangeName, ">");
			break;
	}

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
			return statement(c.loc, q{%s.writeHTMLEscaped((%s).to!string);}, ctx.rangeName, c.value);
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
