module sbylib.editor.util;

string[] importPath() {
    import std.algorithm : filter, map, sort, uniq;
    import std.array : array;
    import std.path : dirName;
    import std.process : executeShell;
    import std.string : split;
    import sbylib.editor.project.metainfo : MetaInfo;

    auto result = executeShell("dub describe --import-paths").output.split("\n").filter!(s => s.length > 0).array;
    result ~= MetaInfo().projectFileList.map!(file => file.dirName).array.sort.uniq.array;

    return result;
}

string[] linkerFlag() {
    import std.process : executeShell;
    import std.json : parseJSON;
    import std.algorithm : filter, map, canFind;
    import std.string : endsWith;
    import std.format : format;
    import std.array : join;
    import std.path : buildPath;

    auto root = executeShell("dub describe").output.parseJSON.object;
    auto packages = root["packages"].array;
    auto rootPackage = packages
        .map!(p => p.object)
        .filter!(obj => obj["name"].str == root["rootPackage"].str)
        .front;

    alias findPackage = (string name) => packages.filter!(p => p.object["name"].str == name).front.object;

    string[] dependentPackageList(string root) {
        void func(string root, ref string[] current) {
            foreach (dependency; findPackage(root)["dependencies"]
                    .array
                    .map!(s => s.str)
                    .filter!(n => current.canFind(n) is false)) {
                current ~= dependency;
                func(dependency, current);
            }
        }
        string[] result;
        func(root, result);
        return result;
    }

    return dependentPackageList(rootPackage["name"].str)
        .filter!(n => n != "sbylib-editor")
        .map!(n => findPackage(n))
        .filter!(p => p["targetFileName"].str.endsWith(".a"))
        .map!(p => [format!"-L-L%s"(buildPath(p["path"].str, p["targetPath"].str)),
                    format!"-L-l%s"(p["targetFileName"].str[3..$-2])])
        .join;
}

string[] versions() {
    import std.algorithm : filter;
    import std.array : array;
    import std.process : executeShell;
    import std.string : split;

    return executeShell("dub describe --data=versions").output.split.filter!(s => s.length > 0).array;
}

string fontPath(string filename) {
    import std.path : buildPath;
    return fontDir.buildPath(filename);
}

string fontDir() {
    import std.path : buildPath;
    return rootDir.buildPath("font");
}

string resourcePath(string filename) {
    import std.path : buildPath;
    return resourceDir.buildPath(filename);
}

string resourceDir() {
    import std.path : buildPath;
    return rootDir.buildPath("resource");
}

string rootDir() {
    import std.algorithm : filter;
    import std.conv : to;
    import std.file : dirEntries, SpanMode;
    import std.path : dirName, buildNormalizedPath;
    import std.string : endsWith;
    
    string file = __FILE_FULL_PATH__.dirName;

    while (file.dirEntries(SpanMode.shallow).filter!(path => path.to!string.endsWith(".dub")).empty) {
        assert(file.dirName != file);
        file = file.dirName;
    }

    return file.buildNormalizedPath();
}

string sbyDir() {
    import std.file : exists, mkdirRecurse;
    import std.path : buildPath;

    auto dir = ".sbylib";
    if (dir.exists == false)
        mkdirRecurse(dir);

    return dir;
}
