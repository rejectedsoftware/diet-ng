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
	assert(dst.data == "<p>Hallo, Welt!</p>", dst.data);

	dst = appender!string;
	dst.compileHTMLDietString!(":uppercase testing", CTX);
	assert(dst.data == "TESTING\n", dst.data);
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
		if (n.name.startsWith(":")) {
			enforcep(n.isTextNode, "Only raw text is currently supported as filter contents.", n.loc);
			n.contents[0].value = runFilter!ALIASES(n.contents[0].value, n.name[1 .. $]);
			n.name = Node.SpecialName.text;
		}
	}

	foreach (ref n; nodes) processNode(n);

	return nodes;
}

private struct DietTraitsAttribute {}

private string runFilter(ALIASES...)(string text, string filter)
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
