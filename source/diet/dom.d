module diet.dom;

import diet.internal.string;


class Node {
	enum SpecialName {
		comment = "//",
		hidden = "//-",
		code = "-",
		text = "|",
		filter = ":" // has a "filterChain" attribute with a space separated list of filter names
	}

	Location loc;
	string name;
	Attribute[] attributes;
	NodeContent[] contents;
	NodeAttribs attribs;

	this(Location loc = Location.init, string name = null, Attribute[] attributes = null, NodeContent[] contents = null, NodeAttribs attribs = NodeAttribs.none)
	{
		this.loc = loc;
		this.name = name;
		this.attributes = attributes;
		this.contents = contents;
		this.attribs = attribs;
	}

	void addText(string text, in ref Location loc)
	{
		if (contents.length && contents[$-1].kind == NodeContent.Kind.text && contents[$-1].loc == loc)
			contents[$-1].value ~= text;
		else contents ~= NodeContent.text(text, loc);
	}

	void stripIfOnlyWhitespace()
	{
		if (contents.length == 1 && contents[0].kind == NodeContent.Kind.text && contents[0].value.ctstrip.length == 0)
			contents = null;
	}

	void stripLeadingWhitespace()
	{
		while (contents.length >= 1 && contents[0].kind == NodeContent.Kind.text) {
			contents[0].value = ctstripLeft(contents[0].value);
			if (contents[0].value.length == 0)
				contents = contents[1 .. $];
			else break;
		}
	}

	void stripTrailingWhitespace()
	{
		while (contents.length >= 1 && contents[$-1].kind == NodeContent.Kind.text) {
			contents[$-1].value = ctstripRight(contents[$-1].value);
			if (contents[$-1].value.length == 0)
				contents = contents[0 .. $-1];
			else break;
		}
	}

	/// Tests if the node consists of only a single, static string.
	bool isTextNode() const { return contents.length == 1 && contents[0].kind == NodeContent.Kind.text; }

	/// Tests if the node consists only of text and interpolations, but doesn't contain child nodes.
	bool isProceduralTextNode() const { import std.algorithm.searching : all; return contents.all!(c => c.kind != NodeContent.Kind.node); }

	string getTextAttribute(string name)
	{
		foreach (a; this.attributes)
			if (a.name == name) {
				assert(a.contents.length == 1 && a.contents[0].kind == AttributeContent.Kind.text);
				return a.contents[0].value;
			}
		return null;
	}

	override string toString() const {
		import std.string : format;
		return format("Node(%s, %s, %s, %s, %s)", this.tupleof);
	}

	override bool opEquals(Object other_) {
		auto other = cast(Node)other_;
		if (!other) return false;
		return this.tupleof == other.tupleof;
	}
}

enum NodeAttribs {
	none = 0,
	translated = 1<<0,  /// Translate node contents
	textNode = 1<<1,    /// All nested lines are treated as text
	rawTextNode = 1<<2, /// All nested lines are treated as raw text (no interpolations or inline tags)
	fitOutside = 1<<3,  /// Don't insert white space outside of the node when generating output (currently ignored by the HTML generator)
	fitInside = 1<<4,   /// Don't insert white space around the node contents when generating output (currently ignored by the HTML generator)
}

struct Attribute {
	string name;
	AttributeContent[] contents;

	@property Attribute dup() const { return Attribute(name, contents.dup); }

	void addText(string str)
	{
		if (contents.length && contents[$-1].kind == AttributeContent.Kind.text)
			contents[$-1].value ~= str;
		else
			contents ~= AttributeContent.text(str);
	}

	void addContents(const(AttributeContent)[] contents)
	{
		if (contents.length > 0 && contents[0].kind == AttributeContent.Kind.text) {
			addText(contents[0].value);
			contents = contents[1 .. $];
		}
		contents ~= contents;
	}
}

struct AttributeContent {
	enum Kind {
		text,
		interpolation,
		rawInterpolation
	}

	Kind kind;
	string value;

	static AttributeContent text(string text) { return AttributeContent(Kind.text, text); }
	static AttributeContent interpolation(string expression) { return AttributeContent(Kind.interpolation, expression); }
	static AttributeContent rawInterpolation(string expression) { return AttributeContent(Kind.rawInterpolation, expression); }
}

struct NodeContent {
	enum Kind {
		node,
		text,
		interpolation,
		rawInterpolation
	}

	Kind kind;
	Location loc;
	Node node;
	string value;

	static NodeContent tag(Node node) { return NodeContent(Kind.node, node.loc, node); }
	static NodeContent text(string text, Location loc) { return NodeContent(Kind.text, loc, Node.init, text); }
	static NodeContent interpolation(string text, Location loc) { return NodeContent(Kind.interpolation, loc, Node.init, text); }
	static NodeContent rawInterpolation(string text, Location loc) { return NodeContent(Kind.rawInterpolation, loc, Node.init, text); }

	bool opEquals(in ref NodeContent other)
	{
		return this.kind == other.kind && this.loc == other.loc && this.node == other.node && this.value == other.value;
	}
}

struct Location {
	string file;
	int line;
}
