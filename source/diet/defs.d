/** Contains common types and constants.
*/
module diet.defs;

import diet.dom;


/** The name of the output range variable within a Diet template.

	D statements can access the variable with this name to directly write to the
	output.
*/
enum dietOutputRangeName = "_diet_output";


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
