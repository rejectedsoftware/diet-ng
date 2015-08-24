/**
	Generic Diet format parser.

	Performs generic parsing of a Diet template file. The resulting AST is
	agnostic to the output format context in which it is used. Format
	specific constructs, such as inline code or special tags, are parsed
	as-is without any preprocessing.

	The supported features of the are:
	$(UL
		$(LI string interpolations)
		$(LI assignment expressions)
		$(LI blocks/extensions)
		$(LI includes)
		$(LI text paragraphs)
		$(LI translation annotations)
		$(LI class and ID attribute shortcuts)
	)
*/
module diet.parser;

import diet.dom;
import diet.exception;
import diet.internal.string;
import diet.input;

import std.algorithm.searching : endsWith, startsWith;
import std.range.primitives : empty, front, popFront, popFrontN;


InputFile[] collectInputFiles(string diet_file)()
{
	assert(false);
}

Node[] parseDiet(string text, string filename = "string")
{
	InputFile[1] f;
	f[0].name = filename;
	f[0].contents = text;
	return parseDiet(f);
}

Node[] parseDiet(InputFile[] files)
{
	return parseDietWithExtensions(files, 0, null);
}

unittest { // test basic functionality
	import std.conv : text;

	Location ln(int l) { return Location("string", l); }

	// simple node
	assert(parseDiet("test") == [
		new Node(ln(0), "test")
	]);

	// nested nodes
	assert(parseDiet("foo\n  bar") == [
		new Node(ln(0), "foo", null, [
			NodeContent.tag(new Node(ln(1), "bar"))
		])
	]);

	// node with id and classes
	assert(parseDiet("test#id.cls1.cls2") == [
		new Node(ln(0), "test", [
			Attribute("id", [AttributeContent.text("id")]),
			Attribute("class", [AttributeContent.text("cls1")]),
			Attribute("class", [AttributeContent.text("cls2")])
		])
	]);

	// node with attributes
	assert(parseDiet("test(foo1=\"bar\", foo2=2+3)") == [
		new Node(ln(0), "test", [
			Attribute("foo1", [AttributeContent.text("bar")]),
			Attribute("foo2", [AttributeContent.interpolation("2+3")])
		])
	]);

	// node with pure text contents
	assert(parseDiet("foo.\n  hello\n      world") == [
		new Node(ln(0), "foo", null, [
			NodeContent.text("hello", ln(1)),
			NodeContent.text("\n    world", ln(2))
		], NodeAttribs.textNode)
	]);

	// translated text
	assert(parseDiet("foo& test") == [
		new Node(ln(0), "foo", null, [
			NodeContent.text("test", ln(0))
		], NodeAttribs.translated)
	]);

	// interpolated text
	assert(parseDiet("foo hello #{\"world\"} bar") == [
		new Node(ln(0), "foo", null, [
			NodeContent.text("hello ", ln(0)),
			NodeContent.interpolation(`"world"`, ln(0)),
			NodeContent.text(" bar", ln(0))
		])
	]);

	// expression
	assert(parseDiet("foo= 1+2") == [
		new Node(ln(0), "foo", null, [
			NodeContent.interpolation(`1+2`, ln(0)),
		])
	], text(parseDiet("foo= 1+2")));

	// raw expression
	assert(parseDiet("foo!= 1+2") == [
		new Node(ln(0), "foo", null, [
			NodeContent.rawInterpolation(`1+2`, ln(0)),
		])
	]);

	// interpolated attribute text
	assert(parseDiet("foo(att='hello #{\"world\"} bar')") == [
		new Node(ln(0), "foo", [
			Attribute("att", [
				AttributeContent.text("hello "),
				AttributeContent.interpolation(`"world"`),
				AttributeContent.text(" bar")
			])
		])
	]);

	// attribute expression
	assert(parseDiet("foo(att=1+2)") == [
		new Node(ln(0), "foo", [
			Attribute("att", [
				AttributeContent.interpolation(`1+2`),
			])
		])
	]);

	// special nodes
	assert(parseDiet("//comment") == [
		new Node(ln(0), "//", null, [NodeContent.text("comment", ln(0))], NodeAttribs.rawTextNode)
	], text(parseDiet("//comment")));
	assert(parseDiet("//-hide") == [
		new Node(ln(0), "//-", null, [NodeContent.text("hide", ln(0))], NodeAttribs.rawTextNode)
	]);
	assert(parseDiet("!!! 5") == [
		new Node(ln(0), "doctype", null, [NodeContent.text("5", ln(0))])
	]);
	assert(parseDiet("<inline>") == [
		new Node(ln(0), "|", null, [NodeContent.text("<inline>", ln(0))])
	]);
}

unittest { // test expected errors
	void testFail(string diet, string msg)
	{
		try {
			parseDiet(diet);
			assert(false, "Expected exception was not thrown.");
		} catch (DietParserException ex) assert(ex.msg == msg, "Unexpected error message: "~ex.msg);
	}

	testFail("+test", "Expected identifier but got '+'.");
	testFail("  test", "First node must not be indented.");
	testFail("test\n  test\n\ttest", "Mismatched indentation style.");
	testFail("test\n\ttest\n\t\t\ttest", "Line is indented too deeply.");
	testFail("test#", "Expected identifier but got nothing.");
	testFail("test.()", "Expected identifier but got '('.");
	testFail("test #.", "Expected '{' following '#'.");
	testFail("test !.", "Expected '{' following '!'.");
	testFail("test ##", "Use '\\#' instead of '##' for escaping.");
	testFail("test !!", "Use '\\!' instead of '!!' for escaping.");
}

unittest { // includes
	Node[] parse(string diet) {
		auto files = [
			InputFile("main.dt", diet),
			InputFile("inc.dt", "p")
		];
		return parseDiet(files);
	}

	void testFail(string diet, string msg)
	{
		try {
			parse(diet);
			assert(false, "Expected exception was not thrown");
		} catch (DietParserException ex) {
			assert(ex.msg == msg, "Unexpected error message: "~ex.msg);
		}
	}

	assert(parse("include inc") == [
		new Node(Location("inc.dt", 0), "p", null, null)
	]);
	testFail("include main", "Recursive include.");
	testFail("include inc2", "Missing include input file: inc2");
	testFail("include #{p}", "Dynamic includes are not supported.");
	testFail("include inc\n\tp", "Includes cannot have children.");
	testFail("p\ninclude inc\n\tp", "Includes cannot have children.");
}

unittest { // extensions
	Node[] parse(string diet) {
		auto files = [
			InputFile("main.dt", diet),
			InputFile("root.dt", "html\n\tblock a\n\tblock b"),
			InputFile("intermediate.dt", "extends root\nblock a\n\tp"),
		];
		return parseDiet(files);
	}

	void testFail(string diet, string msg)
	{
		try {
			parse(diet);
			assert(false, "Expected exception was not thrown");
		} catch (DietParserException ex) {
			assert(ex.msg == msg, "Unexpected error message: "~ex.msg);
		}
	}

	assert(parse("extends root") == [
		new Node(Location("root.dt", 0), "html", null, null)
	]);
	assert(parse("extends root\nblock a\n\tdiv\nblock b\n\tpre") == [
		new Node(Location("root.dt", 0), "html", null, [
			NodeContent.tag(new Node(Location("main.dt", 2), "div", null, null)),
			NodeContent.tag(new Node(Location("main.dt", 4), "pre", null, null))
		])
	]);
	assert(parse("extends intermediate\nblock b\n\tpre") == [
		new Node(Location("root.dt", 0), "html", null, [
			NodeContent.tag(new Node(Location("intermediate.dt", 2), "p", null, null)),
			NodeContent.tag(new Node(Location("main.dt", 2), "pre", null, null))
		])
	]);
	assert(parse("extends intermediate\nblock a\n\tpre") == [
		new Node(Location("root.dt", 0), "html", null, [
			NodeContent.tag(new Node(Location("main.dt", 2), "pre", null, null))
		])
	]);
	assert(parse("extends intermediate\nappend a\n\tpre") == [
		new Node(Location("root.dt", 0), "html", null, [
			NodeContent.tag(new Node(Location("intermediate.dt", 2), "p", null, null)),
			NodeContent.tag(new Node(Location("main.dt", 2), "pre", null, null))
		])
	]);
	assert(parse("extends intermediate\nprepend a\n\tpre") == [
		new Node(Location("root.dt", 0), "html", null, [
			NodeContent.tag(new Node(Location("main.dt", 2), "pre", null, null)),
			NodeContent.tag(new Node(Location("intermediate.dt", 2), "p", null, null))
		])
	]);
}

unittest { // test CTFE-ability
	static const result = parseDiet("foo#id.cls(att=\"val\", att2=1+3, att3='test#{4}it')\n\tbar");
	static assert(result.length == 1);
}

private Node[] parseDietWithExtensions(InputFile[] files, size_t file_index, BlockInfo[string] blocks)
{
	import std.algorithm : countUntil, filter, map;
	import std.array : array;
	import std.path : stripExtension;

	auto nodes = parseDiet(files, file_index, blocks);
	if (nodes[0].name != "extends") return nodes;

	// extract base template name/index
	enforcep(nodes[0].isTextNode, "'extends' cannot contain children or interpolations.", nodes[0].loc);
	string base_template = nodes[0].contents[0].value.ctstrip;
	auto base_idx = files.countUntil!(f => f.name.stripExtension == base_template);
	assert(base_idx >= 0, "Missing base template: "~base_template);

	// collect all blocks
	foreach (n; nodes[1 .. $]) {
		int mode;
		switch (n.name) {
			default: 
				enforcep(false, "Extension templates may only contain blocks definitions at the root level.", n.loc);
				break;
			case "block": mode = 0; break;
			case "prepend": mode = -1; break;
			case "append": mode = 1; break;
		}
		enforcep(n.contents.length > 0 && n.contents[0].kind == NodeContent.Kind.text,
			"'block' must have a name.", n.loc);
		auto name = n.contents[0].value.ctstrip;
		auto contents = n.contents[1 .. $].filter!(n => n.kind == NodeContent.Kind.node).map!(n => n.node).array;
		if (auto pb = name in blocks) {
			if (pb.mode == -1) pb.contents = pb.contents ~ contents;
			else if (pb.mode == 1) pb.contents = contents ~ pb.contents;
			else continue;
			pb.mode = mode;
		} else blocks[name] = BlockInfo(mode, contents);
	}

	// parse base template
	return parseDietWithExtensions(files, base_idx, blocks);
}

private struct BlockInfo {
	int mode = 0; // -1: prepend, 0: replace, 1: append
	Node[] contents;
}

private Node[] parseDiet(InputFile[] files, size_t file_index, BlockInfo[string] blocks)
{
	string indent_style;
	auto loc = Location(files[file_index].name, 0);
	int prevlevel = -1;
	int skiplevel = int.max;
	string input = files[file_index].contents;
	Node[] ret;
	Node[] stack;
	stack.length = 8;
	bool prev_was_include = false;
	bool is_extension = false;

	next_line:
	while (input.length) {
		// skip whitespace at the beginning of the line
		string indent = input.skipIndent();

		// skip empty lines and ignore whitespace on those
		if (input.length == 0 || input[0] == '\n') { input.popFront(); loc.line++; continue; }
		if (input[0] == '\r') { input.popFrontN(input.length >= 2 && input[1] == '\n' ? 2 : 1); loc.line++; continue; }

		enforcep(prevlevel >= 0 || indent.length == 0, prev_was_include ? "Includes cannot have children." : "First node must not be indented.", loc);

		// determine the indentation style (tabs/spaces) from the first indented
		// line of the file
		if (indent.length && !indent_style.length) indent_style = indent;

		// determine nesting level
		int level = 0;
		string textindent;
		if (indent_style.length) {
			while (indent.startsWith(indent_style)) {
				if (level > prevlevel) {
					enforcep((stack[prevlevel].attribs & (NodeAttribs.textNode|NodeAttribs.rawTextNode)) != 0,
						prev_was_include ? "Includes cannot have children." : "Line is indented too deeply.", loc);
					textindent = indent;
					indent = null;
					break;
				}
				level++;
				indent = indent[indent_style.length .. $];
				if (level > skiplevel) {
					skipLine(input, loc);
					continue next_line;
				}
			}
		}
		enforcep(indent.length == 0, "Mismatched indentation style.", loc);
		skiplevel = int.max; // reset skiplevel once a non-skipped node was encountered

		// read the whole line as text if the parent node is a pure text node
		// ("." suffix) or pure raw text node (e.g. comments)
		if (level > prevlevel && prevlevel >= 0) {
			if (stack[prevlevel].attribs & NodeAttribs.textNode) {
				if (!stack[prevlevel].contents.empty)
					stack[prevlevel].addText("\n", loc);
				if (textindent.length) stack[prevlevel].addText(textindent, loc);
				parseTextLine(input, stack[prevlevel], loc);
				continue;
			} else if (stack[prevlevel].attribs & NodeAttribs.rawTextNode) {
				if (!stack[prevlevel].contents.empty)
					stack[prevlevel].addText("\n", loc);
				if (textindent.length) stack[prevlevel].addText(textindent, loc);
				auto tmploc = loc;
				stack[prevlevel].addText(skipLine(input, loc), tmploc);
				continue;
			}
		}

		// parse the line and write it to the stack:

		if (stack.length < level+1) stack.length = level+1;

		if (input.startsWith("include ")) {
			prev_was_include = true;
			input = input[8 .. $];

			auto tmploc = loc;
			auto name = skipLine(input, tmploc).ctstrip;
			Node[] incnodes;

			if (name.startsWith("#{")) {
				enforcep(false, "Dynamic includes are not supported.", tmploc);
			} else {
				import std.path : stripExtension;
				// file include
				size_t fi = size_t.max;
				foreach (i, ref f; files)
					if (f.name.stripExtension == name) {
						fi = i;
						break;
					}
				enforcep(fi != size_t.max, "Missing include input file: "~name, loc);
				enforcep(fi != file_index, "Recursive include.", loc);
			
				incnodes = parseDiet(files, fi, blocks);
			}

			if (level == 0) ret ~= incnodes;
			else foreach (n; incnodes) stack[level-1].contents ~= NodeContent.tag(n);
			prevlevel = level-1;
			continue;
		} else prev_was_include = false;

		if (input.startsWith("block ") && !is_extension) {
			input = input[6 .. $];

			auto tmploc = loc;
			auto name = skipLine(input, tmploc).ctstrip;
			int mode = -1;

			if (auto pb = name in blocks) {
				mode = pb.mode;
				if (pb.mode <= 0) {
					import std.algorithm : map;
					import std.array : array;
					if (level == 0) ret ~= pb.contents;
					else stack[level-1].contents ~= pb.contents.map!(n => NodeContent.tag(n)).array;
				}

				assert(pb.mode <= 0, "Prepend block mode not yet supported.");
			}

			if (mode != 0) {
				// append children of 'block' to its parent
				stack[level] = stack[level-1];
			} else skiplevel = level;
			prevlevel = level;
			continue;
		}

		if (input.startsWith("//")) {
			// comments
			auto n = new Node;
			n.loc = loc;
			if (input[2 .. $].startsWith("-")) { n.name = "//-"; input = input[3 .. $]; }
			else { n.name = "//"; input = input[2 .. $]; }
			n.attribs |= NodeAttribs.rawTextNode;
			auto tmploc = loc;
			n.addText(skipLine(input, loc), tmploc);
			stack[level] = n;
		} else {
			// normal tag line
			stack[level] = parseTagLine(input, loc);

			// test if first node is an "extends" node
			if (prevlevel < 0 && stack[level].name == "extends")
				is_extension = true;
		}

		// add it to its parent contents
		if (level > 0) stack[level-1].contents ~= NodeContent.tag(stack[level]);
		else ret ~= stack[0];

		// remember the nesting level for the next line
		prevlevel = level;
	}

	return ret;
}

private Node parseTagLine(ref string input, ref Location loc)
{
	import std.ascii : isWhite;

	size_t idx = 0;

	auto ret = new Node;
	ret.loc = loc;

	if (input.startsWith("!!! ")) { // legacy doctype support
		input = input[3 .. $];
		ret.name = "doctype";
	} else if (input.startsWith("|")) { // text line
		input = input[1 .. $];
		ret.name = "|";
	} else if (input.startsWith("<")) { // inline HTML/XML
		ret.name = "|";
	} else ret.name = skipIdent(input, idx, ":-_", loc);

	if (ret.name != "|") {
		// node ID
		if (idx < input.length && input[idx] == '#') {
			idx++;
			auto value = skipIdent(input, idx, "-_", loc);
			enforcep(value.length > 0, "Expected id.", loc);
			ret.attributes ~= Attribute("id", [AttributeContent(AttributeContent.Kind.text, value)]);
		}

		// node classes
		while (idx < input.length && input[idx] == '.') {
			if (idx+1 >= input.length || input[idx+1].isWhite)
				goto textBlock;
			idx++;
			auto value = skipIdent(input, idx, "-_", loc);
			enforcep(value.length > 0, "Expected class name identifier.", loc);
			ret.attributes ~= Attribute("class", [AttributeContent(AttributeContent.Kind.text, value)]);
		}

		// generic attributes
		if (idx < input.length && input[idx] == '(')
			parseAttributes(input, idx, ret, loc);
	}

	if (idx < input.length && input[idx] == '&') { ret.attribs |= NodeAttribs.translated; idx++; }

	if (idx+1 < input.length && input[idx .. idx+2] == "!=") {
		idx += 2;
		auto l = loc;
		ret.contents ~= NodeContent.rawInterpolation(ctstrip(skipLine(input, idx, loc)), l);
		input = input[idx .. $];
	} else if (idx < input.length && input[idx] == '=') {
		idx++;
		auto l = loc;
		ret.contents ~= NodeContent.interpolation(ctstrip(skipLine(input, idx, loc)), l);
		input = input[idx .. $];
	} else if (idx < input.length && input[idx] == '.') {
		textBlock:
		ret.attribs |= NodeAttribs.textNode;
		idx++;
		skipLine(input, idx, loc); // ignore the rest of the line
		input = input[idx .. $];
	} else {
		input = input[idx .. $];

		// parse the rest of the line as text contents (if any non-ws)
		parseTextLine(input, ret, loc);
		ret.stripLeadingWhitespace();
	}

	return ret;
}

/**
	Parses a single line of text (possibly containing interpolations and inline tags).

	If there a a newline at the end, it will be appended to the contents of the
	destination node.
*/
private void parseTextLine(ref string input, ref Node dst, ref Location loc)
{
	size_t sidx = 0, idx = 0;

	void flushText()
	{
		if (idx > sidx) dst.addText(input[sidx .. idx], loc);
	}

	while (idx < input.length) {
		char cur = input[idx];
		switch (cur) {
			default: idx++; break;
			case '!', '#':
				flushText();
				idx++;
				enforcep(idx < input.length && (input[idx] == cur || input[idx] == '{'),
					"Expected '{' following '"~cur~"'.", loc);
				enforcep(input[idx] == '{', "Use '\\"~cur~"' instead of '"~cur~cur~"' for escaping.", loc);
				idx++;
				auto expr = skipUntilClosingBrace(input, idx, loc);
				idx++;
				if (cur == '#') dst.contents ~= NodeContent.interpolation(expr, loc);
				else dst.contents ~= NodeContent.rawInterpolation(expr, loc);
				sidx = idx;
				break;
			case '\r':
				flushText();
				idx++;
				if (idx < input.length && input[idx] == '\n') idx++;
				input = input[idx .. $];
				loc.line++;
				return;
			case '\n':
				flushText();
				idx++;
				input = input[idx .. $];
				loc.line++;
				return;
		}
	}

	flushText();
	assert(idx == input.length);
	input = null;
}

private string skipLine(ref string input, ref size_t idx, ref Location loc)
{
	auto sidx = idx;

	while (idx < input.length) {
		char cur = input[idx];
		switch (cur) {
			default: idx++; break;
			case '\r':
				auto ret = input[sidx .. idx];
				idx++;
				if (idx < input.length && input[idx] == '\n') idx++;
				loc.line++;
				return ret;
			case '\n':
				auto ret = input[sidx .. idx];
				idx++;
				loc.line++;
				return ret;
		}
	}

	return input[sidx .. $];
}

private string skipLine(ref string input, ref Location loc)
{
	size_t idx = 0;
	auto ret = skipLine(input, idx, loc);
	input = input[idx .. $];
	return ret;
}

private void parseAttributes(ref string input, ref size_t i, ref Node node, in ref Location loc)
{
	assert(i < input.length && input[i] == '(');
	i++;

	skipWhitespace(input, i);
	while (i < input.length && input[i] != ')') {
		string name = skipIdent(input, i, "-:", loc);
		string value;
		skipWhitespace(input, i);
		if( i < input.length && input[i] == '=' ){
			i++;
			skipWhitespace(input, i);
			enforcep(i < input.length, "'=' must be followed by attribute string.", loc);
			value = skipExpression(input, i, loc);
			assert(i <= input.length);
			if (isStringLiteral(value) && value[0] == '\'') {
				auto tmp = dstringUnescape(value[1 .. $-1]);
				value = '"' ~ dstringEscape(tmp) ~ '"';
			}
		} else value = "true";

		enforcep(i < input.length, "Unterminated attribute section.", loc);
		enforcep(input[i] == ')' || input[i] == ',', "Unexpected text following attribute: '"~input[0..i]~"' ('"~input[i..$]~"')", loc);
		if (input[i] == ',') {
			i++;
			skipWhitespace(input, i);
		}

		if (name == "class" && value == `""`) continue;

		if (isStringLiteral(value)) {
			AttributeContent[] content;
			parseAttributeText(value[1 .. $-1], content, loc);
			node.attributes ~= Attribute(name, content);
		} else {
			node.attributes ~= Attribute(name, [AttributeContent.interpolation(value)]);
		}
	}

	enforcep(i < input.length, "Missing closing clamp.", loc);
	i++;
}

private void parseAttributeText(string input, ref AttributeContent[] dst, in ref Location loc)
{
	size_t sidx = 0, idx = 0;

	void flushText()
	{
		if (idx > sidx) dst ~= AttributeContent.text(input[sidx .. idx]);
	}

	while (idx < input.length) {
		char cur = input[idx];
		switch (cur) {
			default: idx++; break;
			case '\\':
				flushText();
				dst ~= AttributeContent.text(dstringUnescape(sanitizeEscaping(input[idx .. idx+2])));
				idx += 2;
				sidx = idx;
				break;
			case '!', '#':
				flushText();
				idx++;
				enforcep(idx < input.length && (input[idx] == cur || input[idx] == '{'),
					"Expected '{' following '"~cur~"'.", loc);
				enforcep(input[idx] == '{', "Use '\\"~cur~"' instead of '"~cur~cur~"' for escaping.", loc);
				idx++;
				auto expr = dstringUnescape(skipUntilClosingBrace(input, idx, loc));
				idx++;
				if (cur == '#') dst ~= AttributeContent.interpolation(expr);
				else dst ~= AttributeContent.rawInterpolation(expr);
				sidx = idx;
				break;
		}
	}

	flushText();
	input = input[idx .. $];
}

private string skipUntilClosingBrace(in ref string s, ref size_t idx, in ref Location loc)
{
	int level = 0;
	auto start = idx;
	while( idx < s.length ){
		if( s[idx] == '{' ) level++;
		else if( s[idx] == '}' ) level--;
		if( level < 0 ) return s[start .. idx];
		idx++;
	}
	enforcep(false, "Missing closing brace", loc);
	assert(false);
}

private string skipIdent(in ref string s, ref size_t idx, string additional_chars, in ref Location loc)
{
	import std.ascii : isAlpha;

	size_t start = idx;
	while (idx < s.length) {
		if (isAlpha(s[idx])) idx++;
		else if (start != idx && s[idx] >= '0' && s[idx] <= '9') idx++;
		else {
			bool found = false;
			foreach (ch; additional_chars)
				if (s[idx] == ch) {
					found = true;
					idx++;
					break;
				}
			if (!found) {
				enforcep(start != idx, "Expected identifier but got '"~s[idx]~"'.", loc);
				return s[start .. idx];
			}
		}
	}
	enforcep(start != idx, "Expected identifier but got nothing.", loc);
	return s[start .. idx];
}

/// Skips all trailing spaces and tab characters of the input string.
private string skipIndent(ref string input)
{
	size_t idx = 0;
	while (idx < input.length && isIndentChar(input[idx]))
		idx++;
	auto ret = input[0 .. idx];
	input = input[idx .. $];
	return ret;
}

private bool isIndentChar(dchar ch) { return ch == ' ' || ch == '\t'; }

private string skipWhitespace(in ref string s, ref size_t idx)
{
	size_t start = idx;
	while (idx < s.length) {
		if (s[idx] == ' ') idx++;
		else break;
	}
	return s[start .. idx];
}

private bool isStringLiteral(string str)
{
	size_t i = 0;

	// skip leading white space
	while (i < str.length && (str[i] == ' ' || str[i] == '\t')) i++;

	// no string literal inside
	if (i >= str.length) return false;

	char delimiter = str[i++];
	if (delimiter != '"' && delimiter != '\'') return false;

	while (i < str.length && str[i] != delimiter) {
		if (str[i] == '\\') i++;
		i++;
	}

	// unterminated string literal
	if (i >= str.length) return false;

	i++; // skip delimiter

	// skip trailing white space
	while (i < str.length && (str[i] == ' ' || str[i] == '\t')) i++;

	// check if the string has ended with the closing delimiter
	return i == str.length;
}

unittest {
	assert(isStringLiteral(`""`));
	assert(isStringLiteral(`''`));
	assert(isStringLiteral(`"hello"`));
	assert(isStringLiteral(`'hello'`));
	assert(isStringLiteral(` 	"hello"	 `));
	assert(isStringLiteral(` 	'hello'	 `));
	assert(isStringLiteral(`"hel\"lo"`));
	assert(isStringLiteral(`"hel'lo"`));
	assert(isStringLiteral(`'hel\'lo'`));
	assert(isStringLiteral(`'hel"lo'`));
	assert(isStringLiteral(`'#{"address_"~item}'`));
	assert(!isStringLiteral(`"hello\`));
	assert(!isStringLiteral(`"hello\"`));
	assert(!isStringLiteral(`"hello\"`));
	assert(!isStringLiteral(`"hello'`));
	assert(!isStringLiteral(`'hello"`));
	assert(!isStringLiteral(`"hello""world"`));
	assert(!isStringLiteral(`"hello" "world"`));
	assert(!isStringLiteral(`"hello" world`));
	assert(!isStringLiteral(`'hello''world'`));
	assert(!isStringLiteral(`'hello' 'world'`));
	assert(!isStringLiteral(`'hello' world`));
	assert(!isStringLiteral(`"name" value="#{name}"`));
}

private string skipExpression(in ref string s, ref size_t idx, in ref Location loc)
{
	string clamp_stack;
	size_t start = idx;
	outer:
	while (idx < s.length) {
		switch (s[idx]) {
			default: break;
			case '\n', '\r':
				enforcep(false, "Unexpected end of line.", loc);
				break;
			case ',':
				if (clamp_stack.length == 0)
					break outer;
				break;
			case '"', '\'':
				idx++;
				skipAttribString(s, idx, s[idx-1], loc);
				break;
			case '(': clamp_stack ~= ')'; break;
			case '[': clamp_stack ~= ']'; break;
			case '{': clamp_stack ~= '}'; break;
			case ')', ']', '}':
				if (s[idx] == ')' && clamp_stack.length == 0)
					break outer;
				enforcep(clamp_stack.length > 0 && clamp_stack[$-1] == s[idx],
					"Unexpected '"~s[idx]~"'", loc);
				clamp_stack.length--;
				break;
		}
		idx++;
	}

	enforcep(clamp_stack.length == 0, "Expected '"~clamp_stack[$-1]~"' before end of attribute expression.", loc);
	return ctstrip(s[start .. idx]);
}

private string skipAttribString(in ref string s, ref size_t idx, char delimiter, in ref Location loc)
{
	size_t start = idx;
	while( idx < s.length ){
		if( s[idx] == '\\' ){
			// pass escape character through - will be handled later by buildInterpolatedString
			idx++;
			enforcep(idx < s.length, "'\\' must be followed by something (escaped character)!", loc);
		} else if( s[idx] == delimiter ) break;
		idx++;
	}
	enforcep(idx < s.length, "Unterminated attribute string: "~s[start-1 .. $]~"||", loc);
	return s[start .. idx];
}

