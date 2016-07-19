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
	}

	auto dst = appender!string;
	dst.compileHTMLDietString!("p& Hello, World!", CTX);
	assert(dst.data == "<p>Hallo, Welt!</p>", dst.data);
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

private struct DietTraitsAttribute {}

