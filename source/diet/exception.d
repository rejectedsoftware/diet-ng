module diet.exception;

import diet.dom;

alias DietParserException = Exception;

package void enforcep(bool cond, lazy string text, in ref Location loc)
{
	if (__ctfe) {
		import std.string : format;
		assert(cond, format("%s(%s): %s", loc.file, loc.line+1, text));
	} else {
		if (!cond) throw new DietParserException(text, loc.file, loc.line+1);
	}
}
