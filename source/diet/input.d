module diet.input;

@property InputFile[] filesFromGroup(alias FILES_GROUP)()
{
	static assert(FILES_GROUP.expand.length % 2 == 0);
	auto ret = new InputFile[FILES_GROUP.expand.length / 2];
	foreach (i, F; FILES_GROUP.expand) {
		static if (i % 2 == 0) {
			ret[i / 2].name = FILES_GROUP.expand[i+1];
			ret[i / 2].contents = FILES_GROUP.expand[i];
			ret[i / 2].mode = 0;
		}
	}
	return ret;
}

struct InputFile {
	string name;
	int mode = 0; // -1: prepend, 0: replace, 1: append
	string contents;
}
