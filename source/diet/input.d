module diet.input;

@property InputFile[] filesFromGroup(alias FILES_GROUP)()
{
	static assert(FILES_GROUP.expand.length % 2 == 0);
	auto ret = new InputFile[FILES_GROUP.expand.length / 2];
	foreach (i, F; FILES_GROUP.expand) {
		static if (i % 2 == 0) {
			ret[i / 2].name = FILES_GROUP.expand[i+1];
			ret[i / 2].contents = FILES_GROUP.expand[i];
		}
	}
	return ret;
}

enum InputFile[] collectFiles(string root_file) = [InputFile(root_file, import(root_file))]; // TODO!

struct InputFile {
	string name;
	string contents;
}


template Group(A...) {
	import std.typetuple;
	alias expand = TypeTuple!A;
}

template localAliases(int i, ALIASES...)
{
	static if (i < ALIASES.length) {
		import std.conv : to;
		enum string localAliases = "alias ALIASES["~i.to!string~"] "~__traits(identifier, ALIASES[i])~";\n"
			~localAliases!(i+1, ALIASES);
	} else {
		enum string localAliases = "";
	}
}
