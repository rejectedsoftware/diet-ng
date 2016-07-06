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
	import std.algorithm.iteration : map;
	import std.array : array;
	FileInfo[] parsed_files = files.map!(f => FileInfo(f.name, parseDietRaw(f))).array;
	return parseDietWithExtensions(parsed_files, 0, null, null);
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

	// empty tag name (only class)
	assert(parseDiet(".foo") == [
		new Node(ln(0), "", [
			Attribute("class", [AttributeContent.text("foo")])
		])
	]);
	assert(parseDiet("a.download-button\n\t.bs-hbtn.right.black") == [
		new Node(ln(0), "a", [
			Attribute("class", [AttributeContent.text("download-button")]),
		], [
			NodeContent.tag(new Node(ln(1), "", [
				Attribute("class", [AttributeContent.text("bs-hbtn")]),
				Attribute("class", [AttributeContent.text("right")]),
				Attribute("class", [AttributeContent.text("black")])
			]))
		])
	], text(parseDiet("a\n\t.bs-hbtn.right.black")));

	// empty tag name (only id)
	assert(parseDiet("#foo") == [
		new Node(ln(0), "", [
			Attribute("id", [AttributeContent.text("foo")])
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
	assert(parseDiet("foo.\n\thello\n\t   world") == [
		new Node(ln(0), "foo", null, [
			NodeContent.text("hello", ln(1)),
			NodeContent.text("\n   world", ln(2))
		], NodeAttribs.textNode)
	], text(parseDiet("foo.\n\thello\n\t   world")));

	// translated text
	assert(parseDiet("foo& test") == [
		new Node(ln(0), "foo", null, [
			NodeContent.text("test", ln(0))
		], NodeAttribs.translated)
	]);

	// interpolated text
	assert(parseDiet("foo hello #{\"world\"} #bar \\#{baz}") == [
		new Node(ln(0), "foo", null, [
			NodeContent.text("hello ", ln(0)),
			NodeContent.interpolation(`"world"`, ln(0)),
			NodeContent.text(" #bar #{baz}", ln(0))
		])
	]);

	// expression
	assert(parseDiet("foo= 1+2") == [
		new Node(ln(0), "foo", null, [
			NodeContent.interpolation(`1+2`, ln(0)),
		])
	]);

	// expression with empty tag name
	assert(parseDiet("= 1+2") == [
		new Node(ln(0), "", null, [
			NodeContent.interpolation(`1+2`, ln(0)),
		])
	]);

	// raw expression
	assert(parseDiet("foo!= 1+2") == [
		new Node(ln(0), "foo", null, [
			NodeContent.rawInterpolation(`1+2`, ln(0)),
		])
	]);

	// interpolated attribute text
	assert(parseDiet("foo(att='hello #{\"world\"} #bar')") == [
		new Node(ln(0), "foo", [
			Attribute("att", [
				AttributeContent.text("hello "),
				AttributeContent.interpolation(`"world"`),
				AttributeContent.text(" #bar")
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
	]);
	assert(parseDiet("//-hide") == [
		new Node(ln(0), "//-", null, [NodeContent.text("hide", ln(0))], NodeAttribs.rawTextNode)
	]);
	assert(parseDiet("!!! 5") == [
		new Node(ln(0), "doctype", null, [NodeContent.text("5", ln(0))])
	]);
	assert(parseDiet("<inline>") == [
		new Node(ln(0), "|", null, [NodeContent.text("<inline>", ln(0))])
	]);
	assert(parseDiet("|text") == [
		new Node(ln(0), "|", null, [NodeContent.text("text", ln(0))])
	]);
	assert(parseDiet("-if(x)") == [
		new Node(ln(0), "-", null, [NodeContent.text("if(x)", ln(0))])
	]);
	assert(parseDiet(":foo\n\tbar") == [
		new Node(ln(0), ":foo", null, [NodeContent.text("bar", ln(1))], NodeAttribs.rawTextNode)
	]);
	assert(parseDiet(":foo :bar baz") == [
		new Node(ln(0), ":foo", null, [
			NodeContent.tag(new Node(ln(0), ":bar", null, [
				NodeContent.text("baz", ln(0))
			], NodeAttribs.rawTextNode))
		])
	]);

	// nested nodes
	assert(parseDiet("a: b") == [
		new Node(ln(0), "a", null, [
			NodeContent.tag(new Node(ln(0), "b"))
		])
	]);

	assert(parseDiet("a: b\n\tc\nd") == [
		new Node(ln(0), "a", null, [
			NodeContent.tag(new Node(ln(0), "b", null, [
				NodeContent.tag(new Node(ln(1), "c"))
			]))
		]),
		new Node(ln(2), "d")
	], parseDiet("a: b\n\tc\nd").text);

	// inline nodes
	assert(parseDiet("a #[b]") == [
		new Node(ln(0), "a", null, [
			NodeContent.tag(new Node(ln(0), "b"))
		])
	]);

	// whitespace fitting
	assert(parseDiet("a<>") == [
		new Node(ln(0), "a", null, [], NodeAttribs.fitInside|NodeAttribs.fitOutside)
	]);
	assert(parseDiet("a<") == [
		new Node(ln(0), "a", null, [], NodeAttribs.fitInside)
	]);
	assert(parseDiet("a>") == [
		new Node(ln(0), "a", null, [], NodeAttribs.fitOutside)
	]);
}

unittest {
	import std.conv : to;
	Location ln(int l) { return Location("string", l); }

	// angular2 html attributes tests
	assert(parseDiet("div([value]=\"firstName\")") == [
		new Node(ln(0), "div", [
			Attribute("[value]", [
				AttributeContent.text("firstName"),
			])
		])
	]);

	assert(parseDiet("div([attr.role]=\"myRole\")") == [
		new Node(ln(0), "div", [
			Attribute("[attr.role]", [
				AttributeContent.text("myRole"),
			])
		])
	]);

	assert(parseDiet("div([attr.role]=\"{foo:myRole}\")") == [
		new Node(ln(0), "div", [
			Attribute("[attr.role]", [
				AttributeContent.text("{foo:myRole}"),
			])
		])
	]);

	assert(parseDiet("div([attr.role]=\"{foo:myRole, bar:MyRole}\")") == [
		new Node(ln(0), "div", [
			Attribute("[attr.role]", [
				AttributeContent.text("{foo:myRole, bar:MyRole}")
			])
		])
	]);

	assert(parseDiet("div((attr.role)=\"{foo:myRole, bar:MyRole}\")") == [
		new Node(ln(0), "div", [
			Attribute("(attr.role)", [
				AttributeContent.text("{foo:myRole, bar:MyRole}")
			])
		])
	]);

	assert(parseDiet("div([class.extra-sparkle]=\"isDelightful\")") == [
		new Node(ln(0), "div", [
			Attribute("[class.extra-sparkle]", [
				AttributeContent.text("isDelightful")
			])
		])
	]);

	auto t = parseDiet("div((click)=\"readRainbow($event)\")");
	assert(t == [
		new Node(ln(0), "div", [
			Attribute("(click)", [
				AttributeContent.text("readRainbow($event)")
			])
		])
	], to!string(t));

	assert(parseDiet("div([(title)]=\"name\")") == [
		new Node(ln(0), "div", [
			Attribute("[(title)]", [
				AttributeContent.text("name")
			])
		])
	]);

	assert(parseDiet("div(*myUnless=\"myExpression\")") == [
		new Node(ln(0), "div", [
			Attribute("*myUnless", [
				AttributeContent.text("myExpression")
			])
		])
	]);

	assert(parseDiet("div([ngClass]=\"{active: isActive, disabled: isDisabled}\")") == [
		new Node(ln(0), "div", [
			Attribute("[ngClass]", [
				AttributeContent.text("{active: isActive, disabled: isDisabled}")
			])
		])
	]);

	t = parseDiet("div(*ngFor=\"\\#item of list\")");
	assert(t == [
		new Node(ln(0), "div", [
			Attribute("*ngFor", [
				AttributeContent.text("#"),
				AttributeContent.text("item of list")
			])
		])
	], to!string(t));

	t = parseDiet("div(({*ngFor})=\"{args:\\#item of list}\")");
	assert(t == [
		new Node(ln(0), "div", [
			Attribute("({*ngFor})", [
				AttributeContent.text("{args:"),
				AttributeContent.text("#"),
				AttributeContent.text("item of list}")
			])
		])
	], to!string(t));
}

unittest { // test expected errors
	void testFail(string diet, string msg)
	{
		try {
			parseDiet(diet);
			assert(false, "Expected exception was not thrown.");
		} catch (DietParserException ex) assert(ex.msg == msg, "Unexpected error message: "~ex.msg);
	}

	testFail("+test", "Expected node text separated by a space character or end of line, but got '+test'.");
	testFail("  test", "First node must not be indented.");
	testFail("test\n  test\n\ttest", "Mismatched indentation style.");
	testFail("test\n\ttest\n\t\t\ttest", "Line is indented too deeply.");
	testFail("test#", "Expected identifier but got nothing.");
	testFail("test.()", "Expected identifier but got '('.");
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
	testFail("include main", "Dependency cycle detected for this module.");
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
			InputFile("direct.dt", "block a")
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
	assert(parse("extends direct") == []);
	assert(parse("extends direct\nblock a\n\tp") == [
		new Node(Location("main.dt", 2), "p", null, null)
	]);
}

unittest { // test CTFE-ability
	static const result = parseDiet("foo#id.cls(att=\"val\", att2=1+3, att3='test#{4}it')\n\tbar");
	static assert(result.length == 1);
}

private string parseIdent(in ref string str, ref size_t start,
	   	string breakChars, in ref Location loc)
{
	import std.array : back;
	/* The stack is used to keep track of opening and
	closing character pairs, so that when we hit a break char of
	breakChars we know if we can actually break parseIdent.
	*/
	char[] stack;
	size_t i = start;
	outer: while(i < str.length) {
		if(stack.length == 0) {
			foreach(char it; breakChars) {
				if(str[i] == it) {
					break outer;
				}
			}
		}

		if(stack.length && stack.back == str[i]) {
			stack = stack[0 .. $ - 1];
		} else if(str[i] == '"') {
			stack ~= '"';
		} else if(str[i] == '(') {
			stack ~= ')';
		} else if(str[i] == '[') {
			stack ~= ']';
		} else if(str[i] == '{') {
			stack ~= '}';
		}
		++i;
	}

	/* We could have consumed the complete string and still have elements
	on the stack or have ended non breakChars character.
	*/
	if(stack.length == 0) {
		foreach(char it; breakChars) {
			if(str[i] == it) {
				size_t startC = start;
				start = i;
				return str[startC .. i];
			}
		}
	}
	enforcep(false, "Identifier was not ended by any of these characters: "
		~ breakChars, loc);
	assert(false);
}

private Node[] parseDietWithExtensions(FileInfo[] files, size_t file_index, BlockInfo[string] blocks, size_t[] import_stack)
{
	import std.algorithm : all, canFind, countUntil, filter, map;
	import std.array : array;
	import std.path : stripExtension;
	import std.typecons : Nullable;

	auto floc = Location(files[file_index].name, 0);
	enforcep(!import_stack.canFind(file_index), "Dependency cycle detected for this module.", floc);

	auto nodes = files[file_index].nodes;
	if (!nodes.length) return null;

	if (nodes[0].name == "extends") {
		// extract base template name/index
		enforcep(nodes[0].isTextNode, "'extends' cannot contain children or interpolations.", nodes[0].loc);
		enforcep(nodes[0].attributes.length == 0, "'extends' cannot have attributes.", nodes[0].loc);

		string base_template = nodes[0].contents[0].value.ctstrip;
		auto base_idx = files.countUntil!(f => matchesName(f.name, base_template));
		assert(base_idx >= 0, "Missing base template: "~base_template);

		// collect all blocks
		foreach (n; nodes[1 .. $]) {
			BlockInfo.Mode mode;
			switch (n.name) {
				default:
					enforcep(false, "Extension templates may only contain blocks definitions at the root level.", n.loc);
					break;
				case "//", "//-": continue; // also allow comments at the root level
				case "block": mode = BlockInfo.Mode.replace; break;
				case "prepend": mode = BlockInfo.Mode.prepend; break;
				case "append": mode = BlockInfo.Mode.append; break;
			}
			enforcep(n.contents.length > 0 && n.contents[0].kind == NodeContent.Kind.text,
				"'block' must have a name.", n.loc);
			auto name = n.contents[0].value.ctstrip;
			auto contents = n.contents[1 .. $].filter!(n => n.kind == NodeContent.Kind.node).map!(n => n.node).array;
			if (auto pb = name in blocks) {
				if (pb.mode == BlockInfo.Mode.prepend) pb.contents = pb.contents ~ contents;
				else if (pb.mode == BlockInfo.Mode.append) pb.contents = contents ~ pb.contents;
				else continue;
				pb.mode = mode;
			} else blocks[name] = BlockInfo(mode, contents);
		}

		// parse base template
		return parseDietWithExtensions(files, base_idx, blocks, import_stack ~ file_index);
	}

	static string extractFilename(Node n)
	{
		enforcep(n.contents.length >= 1 && n.contents[0].kind != NodeContent.Kind.node,
			"Missing block name.", n.loc);
		enforcep(n.contents[0].kind == NodeContent.Kind.text,
			"Dynamic includes are not supported.", n.loc);
		enforcep(n.contents.length == 1 || n.contents[1 .. $].all!(nc => nc.kind == NodeContent.Kind.node),
			"'"~n.name~"' must only contain a block name and child nodes.", n.loc);
		enforcep(n.attributes.length == 0, "'"~n.name~"' cannot have attributes.", n.loc);
		return n.contents[0].value.ctstrip;
	}

	Nullable!(Node[]) processNode(Node n) {
		Nullable!(Node[]) ret;

		void insert(Node[] nodes) {
			foreach (i, n; nodes) {
				auto np = processNode(n);
				if (!np.isNull()) {
					if (ret.isNull) ret = nodes[0 .. i];
					ret ~= np;
				} else if (!ret.isNull) ret ~= n;
			}
			if (ret.isNull && nodes.length) ret = nodes;
		}

		if (n.name == "block") {
			auto name = extractFilename(n);
			auto pb = name in blocks;

			if (pb && pb.mode == BlockInfo.Mode.prepend)
				insert(pb.contents);
			if (!pb || pb.mode != BlockInfo.Mode.replace)
				insert(n.contents[1 .. $].map!((nc) {
					assert(nc.kind == NodeContent.Kind.node, "Block contains non-node child!?");
					return nc.node;
				}).array);
			if (pb && pb.mode != BlockInfo.Mode.prepend)
				insert(pb.contents);

			if (ret.isNull) ret = [];
		} else if (n.name == "include") {
			auto name = extractFilename(n);
			enforcep(n.contents.length == 1, "Includes cannot have children.", n.loc);
			auto fidx = files.countUntil!(f => matchesName(f.name, name));
			enforcep(fidx >= 0, "Missing include input file: "~name, n.loc);
			insert(parseDietWithExtensions(files, fidx, null, import_stack ~ file_index));
		} else {
			n.contents.modifyArray!((nc) {
				Nullable!(NodeContent[]) rn;
				if (nc.kind == NodeContent.Kind.node) {
					auto mod = processNode(nc.node);
					if (!mod.isNull()) rn = mod.map!(n => NodeContent.tag(n)).array;
				}
				assert(rn.isNull || rn.get.all!(n => n.node.name != "block"));
				return rn;
			});
		}

		assert(ret.isNull || ret.get.all!(n => n.name != "block"));

		return ret;
	}

	nodes.modifyArray!(processNode);

	assert(nodes.all!(n => n.name != "block"));

	return nodes;
}

private struct BlockInfo {
	enum Mode {
		prepend,
		replace,
		append
	}
	Mode mode = Mode.replace;
	Node[] contents;
}

private struct FileInfo {
	string name;
	Node[] nodes;
}

private Node[] parseDietRaw(InputFile file)
{
	import std.algorithm.iteration : map;
	import std.array : array;

	string indent_style;
	auto loc = Location(file.name, 0);
	int prevlevel = -1;
	string input = file.contents;
	Node[] ret;
	// nested stack of nodes
	// the first dimension is corresponds to indentation based nesting
	// the second dimension is for in-line nested nodes
	Node[][] stack;
	stack.length = 8;

	next_line:
	while (input.length) {
		Node pnode;
		if (prevlevel >= 0 && stack[prevlevel].length) pnode = stack[prevlevel][$-1];

		// skip whitespace at the beginning of the line
		string indent = input.skipIndent();

		// skip empty lines and ignore whitespace on those
		if (input.length == 0 || input[0] == '\n') { input.popFront(); loc.line++; continue; }
		if (input[0] == '\r') { input.popFrontN(input.length >= 2 && input[1] == '\n' ? 2 : 1); loc.line++; continue; }

		enforcep(prevlevel >= 0 || indent.length == 0, "First node must not be indented.", loc);

		// determine the indentation style (tabs/spaces) from the first indented
		// line of the file
		if (indent.length && !indent_style.length) indent_style = indent;

		// determine nesting level
		bool is_text_line = pnode && (pnode.attribs & (NodeAttribs.textNode|NodeAttribs.rawTextNode)) != 0;
		int level = 0;
		if (indent_style.length) {
			while (indent.startsWith(indent_style)) {
				if (level > prevlevel) {
					enforcep(is_text_line, "Line is indented too deeply.", loc);
					break;
				}
				level++;
				indent = indent[indent_style.length .. $];
			}
		}

		enforcep(is_text_line || indent.length == 0, "Mismatched indentation style.", loc);

		// read the whole line as text if the parent node is a pure text node
		// ("." suffix) or pure raw text node (e.g. comments)
		if (level > prevlevel && prevlevel >= 0) {
			if (pnode.attribs & NodeAttribs.textNode) {
				if (!pnode.contents.empty)
					pnode.addText("\n", loc);
				if (indent.length) pnode.addText(indent, loc);
				parseTextLine(input, pnode, loc);
				continue;
			} else if (pnode.attribs & NodeAttribs.rawTextNode) {
				if (!pnode.contents.empty)
					pnode.addText("\n", loc);
				if (indent.length) pnode.addText(indent, loc);
				auto tmploc = loc;
				pnode.addText(skipLine(input, loc), tmploc);
				continue;
			}
		}

		// parse the line and write it to the stack:

		if (stack.length < level+1) stack.length = level+1;

		if (input.startsWith("//")) {
			// comments
			auto n = new Node;
			n.loc = loc;
			if (input[2 .. $].startsWith("-")) { n.name = "//-"; input = input[3 .. $]; }
			else { n.name = "//"; input = input[2 .. $]; }
			n.attribs |= NodeAttribs.rawTextNode;
			auto tmploc = loc;
			n.addText(skipLine(input, loc), tmploc);
			stack[level] = [n];
		} else if (input.startsWith('-')) {
			// D statements
			input = input[1 .. $];
			auto n = new Node;
			n.loc = loc;
			n.name = "-";
			auto tmploc = loc;
			n.addText(skipLine(input, loc), tmploc);
			stack[level] = [n];
		} else if (input.startsWith(':')) {
			// filters
			stack[level] = [];

			do {
				input = input[1 .. $];
				size_t idx = 0;
				auto fname = skipIdent(input, idx, "-_", loc);
				input = input[idx .. $];

				Node chn = new Node;
				chn.loc = loc;
				chn.name = ":" ~ fname;
				stack[level] ~= chn;

				if (input.startsWith(' ')) input = input[1 .. $];
			} while (input.startsWith(':'));

			stack[level][$-1].attribs = NodeAttribs.rawTextNode;
			auto tmploc = loc;
			auto trailing = skipLine(input, loc);
			if (trailing.length) stack[level][$-1].addText(trailing, tmploc);
		} else {
			// normal tag line
			bool has_nested;
			stack[level] = null;
			do stack[level] ~= parseTagLine(input, loc, has_nested);
			while (has_nested);
		}

		// add it to its parent contents
		foreach (i; 1 .. stack[level].length)
			stack[level][i-1].contents ~= NodeContent.tag(stack[level][i]);
		if (level > 0) stack[level-1][$-1].contents ~= NodeContent.tag(stack[level][0]);
		else ret ~= stack[0][0];

		// remember the nesting level for the next line
		prevlevel = level;
	}

	return ret;
}

private Node parseTagLine(ref string input, ref Location loc, out bool has_nested)
{
	import std.ascii : isWhite;

	size_t idx = 0;

	auto ret = new Node;
	ret.loc = loc;

	if (input.startsWith("!!! ")) { // legacy doctype support
		input = input[4 .. $];
		ret.name = "doctype";
		parseTextLine(input, ret, loc);
		return ret;
	} else if (input.startsWith('|')) { // text line
		input = input[1 .. $];
		ret.name = "|";
	} else if (input.startsWith('<')) { // inline HTML/XML
		ret.name = "|";
		parseTextLine(input, ret, loc);
		return ret;
	} else {
		ret.name = skipIdent(input, idx, ":-_", loc, true);
		// a trailing ':' is not part of the tag name, but signals a nested node
		if (ret.name.endsWith(":")) {
			ret.name = ret.name[0 .. $-1];
			idx--;
		} else {
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

			if (idx < input.length && input[idx] == '<') {
				idx++;
				ret.attribs |= NodeAttribs.fitInside;
			}

			if (idx < input.length && input[idx] == '>') {
				idx++;
				ret.attribs |= NodeAttribs.fitOutside;
			}
		}
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
	} else if (idx < input.length && input[idx] == ':') {
		idx++;

		// skip trailing whitespace (but no line breaks)
		while (idx < input.length && (input[idx] == ' ' || input[idx] == '\t'))
			idx++;

		// see if we got anything left on the line
		if (idx < input.length) {
			if (input[idx] == '\n' || input[idx] == '\r') {
				// FIXME: should we rather error out here?
				skipLine(input, idx, loc);
			} else {
				// leaves the rest of the line to parse another tag
				has_nested = true;
			}
		}
		input = input[idx .. $];
	} else {
		if (idx < input.length && input[idx] == ' ') {
			// parse the rest of the line as text contents (if any non-ws)
			input = input[idx+1 .. $];
			parseTextLine(input, ret, loc);
		} else if (ret.name == "|") {
			// allow omitting the whitespace for "|" text nodes
			parseTextLine(input, ret, loc);
		} else {
			import std.string : strip;

			auto remainder = skipLine(input, idx, loc);
			input = input[idx .. $];
			enforcep(remainder.strip().length == 0,
				"Expected node text separated by a space character or end of line, but got '"~remainder~"'.", loc);
		}
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
	import std.algorithm.comparison : among;

	size_t sidx = 0, idx = 0;

	void flushText()
	{
		if (idx > sidx) dst.addText(input[sidx .. idx], loc);
	}

	while (idx < input.length) {
		char cur = input[idx];
		switch (cur) {
			default: idx++; break;
			case '\\':
				if (idx+1 < input.length && input[idx+1].among('#', '!')) {
					flushText();
					sidx = idx+1;
					idx += 2;
				} else idx++;
				break;
			case '!', '#':
				if (idx+1 < input.length && input[idx+1] == '{') {
					flushText();
					idx += 2;
					auto expr = skipUntilClosingBrace(input, idx, loc);
					idx++;
					if (cur == '#') dst.contents ~= NodeContent.interpolation(expr, loc);
					else dst.contents ~= NodeContent.rawInterpolation(expr, loc);
					sidx = idx;
				} else if (cur == '#' && idx+1 < input.length && input[idx+1] == '[') {
					flushText();
					idx += 2;
					auto tag = skipUntilClosingBracket(input, idx, loc);
					idx++;
					bool has_nested;
					dst.contents ~= NodeContent.tag(parseTagLine(tag, loc, has_nested));
					enforcep(!has_nested, "Nested inline tags not allowed.", loc);
					sidx = idx;
				} else idx++;
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
		string name = parseIdent(input, i, ",)=", loc);
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
				if (idx+1 < input.length && input[idx+1] == '{') {
					flushText();
					idx += 2;
					auto expr = dstringUnescape(skipUntilClosingBrace(input, idx, loc));
					idx++;
					if (cur == '#') dst ~= AttributeContent.interpolation(expr);
					else dst ~= AttributeContent.rawInterpolation(expr);
					sidx = idx;
				} else idx++;
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
		enforcep(s[idx] != '\n', "Missing '}' before end of line.", loc);
		if( level < 0 ) return s[start .. idx];
		idx++;
	}
	enforcep(false, "Missing closing brace", loc);
	assert(false);
}

private string skipUntilClosingBracket(in ref string s, ref size_t idx, in ref Location loc)
{
	int level = 0;
	auto start = idx;
	while( idx < s.length ){
		if( s[idx] == '[' ) level++;
		else if( s[idx] == ']' ) level--;
		enforcep(s[idx] != '\n', "Missing ']' before end of line.", loc);
		if( level < 0 ) return s[start .. idx];
		idx++;
	}
	enforcep(false, "Missing closing brace", loc);
	assert(false);
}

private string skipIdent(in ref string s, ref size_t idx, string additional_chars, in ref Location loc, bool accept_empty = false)
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
				enforcep(accept_empty || start != idx, "Expected identifier but got '"~s[idx]~"'.", loc);
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

private bool matchesName(string filename, string logical_name)
{
	if (filename == logical_name) return true;
	if (filename.endsWith(".dt") && filename[0 .. $-3] == logical_name) return true;
	return false;
}

private void modifyArray(alias modify, T)(ref T[] arr)
{
	size_t i = 0;
	while (i < arr.length) {
		auto mod = modify(arr[i]);
		if (mod.isNull()) i++;
		else {
			arr = arr[0 .. i] ~ mod.get() ~ arr[i+1 .. $];
			i += mod.length;
		}
	}
}
