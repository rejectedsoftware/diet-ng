/** Definitions to support customization of the Diet compilation process.
*/
module diet.traits;

import diet.dom;


/** Marks a struct as a Diet traits container.
*/
@property DietTraitsAttribute dietTraits() { return DietTraitsAttribute.init; }

///
unittest {
	import diet.html : compileHTMLDietString;
	import std.array : appender, array;
	import std.string : toUpper;

	@dietTraits
	static struct CTX {
		static string translate(string text) {
			return text == "Hello, World!" ? "Hallo, Welt!" : text;
		}

		static string filterUppercase(I)(I input) {
			return input.toUpper();
		}
	}

	auto dst = appender!string;
	dst.compileHTMLDietString!("p& Hello, World!", CTX);
	assert(dst.data == "<p>Hallo, Welt!</p>");

	dst = appender!string;
	dst.compileHTMLDietString!(":uppercase testing", CTX);
	assert(dst.data == "TESTING");
}

/** Translates a line of text based on the traits passed to the Diet parser.

	The input text may contain string interpolations of the form `#{...}` or
	`!{...}`, where the contents form an arbitrary D expression. The
	translation function is required to pass these through unmodified.
*/
string translate(ALIASES...)(string text)
{
	import std.traits : hasUDA;

	foreach (A; ALIASES)
		static if (hasUDA!(A, DietTraitsAttribute))
			static if (is(typeof(A.translate)))
				text = A.translate(text);
	return text;
}

Node[] applyTraits(ALIASES...)(Node[] nodes)
{
	import diet.exception;
	import std.algorithm.searching : startsWith;
	import std.array : split;

	void processNode(ref Node n)
	{
		// process children first
		for (size_t i = 0; i < n.contents.length;) {
			auto nc = n.contents[i];
			if (nc.kind == NodeContent.Kind.node) {
				processNode(nc.node);
				if (nc.node.name == Node.SpecialName.text) {
					n.contents = n.contents[0 .. i] ~ nc.node.contents ~ n.contents[i+1 .. $];
					i += nc.node.contents.length;
				} else i++;
			} else i++;
		}

		// then consolidate text
		for (size_t i = 1; i < n.contents.length;) {
			if (n.contents[i-1].kind == NodeContent.Kind.text && n.contents[i].kind == NodeContent.Kind.text) {
				n.contents[i-1].value ~= n.contents[i].value;
				n.contents = n.contents[0 .. i] ~ n.contents[i+1 .. $];
			} else i++;
		}

		// finally process filters
		if (n.name == Node.SpecialName.filter) {
			enforcep(n.isProceduralTextNode, "Only text is supported as filter contents.", n.loc);
			auto chain = n.getTextAttribute("filterChain").split(' ');
			n.attributes = null;
			n.attribs = NodeAttribs.none;

			if (n.isTextNode) {
				while (chain.length) {
					if (hasFilterCT!ALIASES(chain[$-1])) {
						n.contents[0].value = runFilterCT!ALIASES(n.contents[0].value, chain[$-1]);
						chain.length--;
					} else break;
				}
			}

			if (!chain.length) n.name = Node.SpecialName.text;
			else {
				n.name = Node.SpecialName.code;
				n.contents = [NodeContent.text(generateFilterChainMixin(chain, n.contents), n.loc)];
			}
		}
	}

	foreach (ref n; nodes) processNode(n);

	return nodes;
}

void registerFilter(string name, FilterCallback filter)
{
	s_filters[name] = filter;
}

void filter(in char[] input, string filter, scope void delegate(in char[]) @safe nothrow output)
{
	if (auto pf = filter in s_filters) (*pf)(input, output);
	else output(input);
}

alias FilterCallback = void delegate(in char[] input, scope void delegate(in char[]) @safe nothrow output);

FilterCallback[string] s_filters;

private string generateFilterChainMixin(string[] chain, NodeContent[] contents)
{
	import std.format : format;
	import diet.exception : enforcep;
	import diet.internal.string : dstringEscape;

	string ret = `{ import std.array : appender; import std.format : formattedWrite; `;
	auto tloname = format("__f%s", chain.length);

	if (contents.length == 1 && contents[0].kind == NodeContent.Kind.text) {
		ret ~= q{enum %s = "%s";}.format(tloname, dstringEscape(contents[0].value));
	} else {
		ret ~= q{auto %s_app = appender!(char[])();}.format(tloname);
		foreach (c; contents) {
			switch (c.kind) {
				default: assert(false, "Unexpected node content in filter.");
				case NodeContent.Kind.text:
					ret ~= q{%s_app.put("%s");}.format(tloname, dstringEscape(c.value));
					break;
				case NodeContent.Kind.rawInterpolation:
					ret ~= q{%s_app.formattedWrite("%%s", %s);}.format(tloname, c.value);
					break;
				case NodeContent.Kind.interpolation:
					enforcep(false, "Raw interpolations are not supported within filter contents.", c.loc);
					break;
			}
			ret ~= "\n";
		}
		ret ~= q{auto %s = %s_app.data;}.format(tloname, tloname);
	}

	foreach_reverse (i, f; chain) {
		ret ~= "\n";
		string iname = format("__f%s", i+1);
		string oname;
		if (i > 0) {
			oname = format("__f%s_app", i);
			ret ~= q{auto %s = appender!(char[]);}.format(oname);
		} else oname = "_output_";
		ret ~= q{%s.filter("%s", s => %s.put(s));}.format(iname, dstringEscape(f), oname);
		if (i > 0) ret ~= q{auto __f%s = %s.data;}.format(i, oname);
	}

	return ret ~ `}`;
}

unittest {
	import std.array : appender;
	import diet.html : compileHTMLDietString;

	@dietTraits
	static struct CTX {
		static string filterFoo(string str) { return "("~str~")"; }
	}

	registerFilter("foo", (input, scope output) { output("(R"); output(input); output("R)"); });
	registerFilter("bar", (input, scope output) { output("(RB"); output(input); output("RB)"); });

	auto dst = appender!string;
	dst.compileHTMLDietString!(":foo text", CTX);
	assert(dst.data == "(text)");

	dst = appender!string;
	dst.compileHTMLDietString!("| text", CTX);
	assert(dst.data == "text");

	dst = appender!string;
	dst.compileHTMLDietString!(":foo :foo text", CTX);
	assert(dst.data == "((text))");

	dst = appender!string;
	dst.compileHTMLDietString!(":bar :foo text", CTX);
	assert(dst.data == "(RB(text)RB)");

	dst = appender!string;
	dst.compileHTMLDietString!(":foo :bar text", CTX);
	assert(dst.data == "(R(RBtextRB)R)");

	dst = appender!string;
	dst.compileHTMLDietString!(":foo text !{1}", CTX);
	assert(dst.data == "(Rtext 1R)");
}

private struct DietTraitsAttribute {}

private bool hasFilterCT(ALIASES...)(string filter)
{
	alias Filters = FiltersFromAliases!ALIASES;
	static if (Filters.length) {
		switch (filter) {
			default: return false;
			foreach (F; FiltersFromAliases!ALIASES) {
				case FilterName!F: return true;
			}
		}
	} else return false;
}

private string runFilterCT(ALIASES...)(string text, string filter)
{
	alias Filters = FiltersFromAliases!ALIASES;
	static if (Filters.length) {
		switch (filter) {
			default: return text; // FIXME: error out?
			foreach (F; FiltersFromAliases!ALIASES) {
				case FilterName!F: return F(text);
			}
		}
	} else return text; // FIXME: error out?
}

private template FiltersFromAliases(ALIASES...)
{
	import std.meta : AliasSeq;
	import std.traits : hasUDA;

	template impl(size_t i) {
		static if (i < ALIASES.length) {
			static if (hasUDA!(ALIASES[i], DietTraitsAttribute)) {
				// FIXME: merge lists avoiding duplicates
				alias impl = AliasSeq!(FiltersFromContext!(ALIASES[i]), impl!(i+1));
			} else alias impl = impl!(i+1);
		} else alias impl = AliasSeq!();
	}
	alias FiltersFromAliases = impl!0;
}

private template FiltersFromContext(Context)
{
	import std.meta : AliasSeq;
	import std.algorithm.searching : startsWith;

	alias members = AliasSeq!(__traits(allMembers, Context));
	template impl(size_t i) {
		static if (i < members.length) {
			static if (members[i].startsWith("filter") && members[i].length > 6)
				alias impl = AliasSeq!(__traits(getMember, Context, members[i]), impl!(i+1));
			else alias impl = impl!(i+1);
		} else alias impl = AliasSeq!();
	}
	alias FiltersFromContext = impl!0;
}

private template FilterName(alias FilterFunction)
{
	import std.algorithm.searching : startsWith;
	import std.ascii : toLower;

	enum ident = __traits(identifier, FilterFunction);
	static assert(ident.startsWith("filter") && ident.length > 6,
		"Filter function must start with \"filter\" and must have a non-zero length suffix");
	enum FilterName = ident[6].toLower ~ ident[7 .. $];
}
