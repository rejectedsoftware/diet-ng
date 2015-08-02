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
	string ret = "import std.conv : to;\n";
	foreach (n; nodes)
		ret ~= ctx.getHTMLMixin(n, range_name);
	return ret;
}

unittest {
	import diet.parser;
	void test(string src)(string expected) {
		import std.array : appender;
		static const n = parseDiet(src);
		auto __output = appender!string();
		pragma(msg, getHTMLMixin(n));
		mixin(getHTMLMixin(n));
		assert(__output.data == expected, __output.data);
	}

	test!"doctype html\nfoo(test=true)"("<!DOCTYPE html><foo test></foo>");
	test!"doctype X\nfoo(test=true)"("<!DOCTYPE X><foo test=\"test\"></foo>");
	test!"foo(test=2+3)"("<foo test=\"5\"></foo>");
	test!"foo(test='#{2+3}')"("<foo test=\"5\"></foo>");
}

private string getHTMLMixin(ref CTX ctx, in Node node, string range_name = defaultOutputRangeName)
{
	switch (node.name) {
		case "doctype", "!!!": return ctx.getDoctypeMixin(node, range_name);
		default: return ctx.getElementMixin(node, range_name);
	}
}

private string getDoctypeMixin(ref CTX ctx, in Node node, string range_name)
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

	return statement(node.loc, q{%s.put("<%s>");}, range_name, dstringEscape(doctype_str));
}

private string getElementMixin(ref CTX ctx, in Node node, string range_name)
{
	// write tag name
	string ret = statement(node.loc, q{%s.put("<%s");}, range_name, node.name);

	// write attributes
	foreach (att; node.attributes) {
		bool is_expr = att.values.length == 1 && att.values[0].kind == AttributeContent.Kind.interpolation;

		if (is_expr) {
			auto expr = att.values[0].value;

			if (expr == "true") {
				if (ctx.isHTML5) ret ~= statement(node.loc, q{%s.put(" %s");}, range_name, att.name);
				else ret ~= statement(node.loc, q{%s.put(" %s=\"%s\"");}, range_name, att.name, att.name);
				continue;
			}

			ret ~= statement(node.loc, q{static if (is(typeof(%s) == bool)) }~'{', expr);
			if (ctx.isHTML5) ret ~= statement(node.loc, q{if (%s) %s.put(" %s");}, expr, range_name, att.name);
			else ret ~= statement(node.loc, q{if (%s) %s.put(" %s=\"%s\"");}, expr, range_name, att.name, att.name);
			ret ~= statement(node.loc, "} else {");
		}

		ret ~= statement(node.loc, q{%s.put(" %s=\"");}, range_name, att.name);
		foreach (i, v; att.values) {
			final switch (v.kind) with (AttributeContent.Kind) {
				case text:
					ret ~= rawText(node.loc, range_name, htmlAttribEscape(v.value));
					break;
				case interpolation, rawInterpolation:
					ret ~= statement(node.loc, q{%s.writeHTMLAttribEscaped((%s).to!string);}, range_name, v.value);
					break;
			}
		}
		ret ~= rawText(node.loc, range_name, "\"");

		if (is_expr) ret ~= statement(node.loc, "}");
	}

	// determine if we need a closing tag or have a singular tag
	switch (node.name) {
		case "area", "base", "basefont", "br", "col", "embed", "frame",	"hr", "img", "input",
				"keygen", "link", "meta", "param", "source", "track", "wbr":
			enforcep(!node.contents.length, "Singular HTML element '"~node.name~"' may not have contents.", node.loc);
			ret ~= rawText(node.loc, range_name, "/>");
		default:
			ret ~= rawText(node.loc, range_name, ">");
			break;
	}

	void prettyNewLine() {
		import std.array : replicate;
		if (ctx.pretty) ret ~= rawText(node.loc, range_name, "\n"~"\t".replicate(ctx.depth));
	}

	// write contents
	foreach (c; node.contents) {
		final switch (c.kind) with (NodeContent.Kind) {
			case node:
				prettyNewLine();
				ctx.depth++;
				ret ~= getElementMixin(ctx, c.node, range_name);
				ctx.depth--;
				prettyNewLine();
				break;
			case text:
				ret ~= rawText(c.loc, range_name, c.value);
				break;
			case interpolation:
				ret ~= statement(c.loc, q{%s.writeHTMLEscaped((%s).to!string);}, range_name, c.value);
				break;
			case rawInterpolation:
				ret ~= statement(c.loc, q{%s.put((%s).to!string);}, range_name, c.value);
				break;
		}
	}

	// write end tag
	ret ~= statement(node.loc, q{%s.put("</%s>");}, range_name, node.name);

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
	bool pretty = true;
	int depth = 0;
}
