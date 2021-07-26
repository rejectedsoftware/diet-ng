import diet.input;
import diet.internal.string : dstringEscape;
import diet.parser;
import diet.dom;
import std.algorithm.sorting : sort;
import std.file;
import std.path;
import std.stdio;

int main(string[] args)
{
	if (args.length < 2) {
		writefln("USAGE: %s <base-directory> [<import-directory1> [...]]\n");
		return 1;
	}

	void[0][TranslationKey] key_set;

	void collectRec(Node n)
	{
		if (n.translationKey.length) {
			auto template_name = n.loc.file.baseName.stripExtension;
			key_set[TranslationKey(n.translationKey, template_name)] = (void[0]).init;
		}

		foreach (nc; n.contents)
			if (nc.kind == NodeContent.Kind.node)
				collectRec(nc.node);
	}

	foreach (dir; args[1 .. $]) {
		foreach (de; dirEntries(dir, SpanMode.shallow)) {
			InputFile f;
			f.name = de.name.baseName;
			f.contents = (cast(char[])read(de.name)).idup;
			//auto inputs = rtGetInputs(de.name.baseName, args[1 .. $]);
			auto nodes = parseDietRaw!identity(f);
			foreach (n; nodes)
				collectRec(n);
		}
	}

	auto keys = key_set.keys;
	keys.sort!((a, b) {
		if (a.context != b.context) return a.context < b.context;
		if (a.text != b.text) return a.text < b.text;
		//if (a.mtext != b.mtext) return a.mtext < b.mtext;
		return false;
	});


	writeln("msgid \"\"");
	writeln("msgstr \"\"");
	writeln("\"Content-Type: text/plain; charset=UTF-8\\n\"");
	writeln("\"Content-Transfer-Encoding: 8bit\\n\"");
	foreach (key; keys) {
		writefln("\nmsgctxt \"%s\"", dstringEscape(key.context));
		writefln("msgid \"%s\"", dstringEscape(key.text));
		writeln("msgstr \"\"");
	}

	return 0;
}

struct TranslationKey { string text; string context; }
