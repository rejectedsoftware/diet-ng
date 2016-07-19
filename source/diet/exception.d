/** Contains exception type definitions specific to this package.
*/
module diet.exception;

import diet.dom;

/// Thrown by the parser for malformed input.
alias DietParserException = Exception;

package void enforcep(bool cond, lazy string text, in ref Location loc)
{
	if (__ctfe) {
		import std.conv : to;
		assert(cond, loc.file~"("~(loc.line+1).to!string~"): "~text);
	} else {
		if (!cond) throw new DietParserException(text, loc.file, loc.line+1);
	}
}
