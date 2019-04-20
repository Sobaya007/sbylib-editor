module sbylib.editor.util;

string[] importPath() {
    import sbylib.editor.tools.dub : Dub;

    return Dub.getImportPath()~ findPhobosPath();
}

auto dependentLibraries() {
    import std.process : executeShell;
    import std.json : parseJSON;
    import std.algorithm : filter, map, canFind, sort, uniq;
    import std.string : endsWith;
    import std.format : format;
    import std.array : join, array;
    import std.path : buildPath;
    import sbylib.editor.tools.dub : Dub;

    const data = Dub.describe();

    string[] dependentPackageList(string root) {
        void func(string root, ref string[] current) {
            foreach (dependency; data.findPackage(root).dependencies
                    .filter!(n => current.canFind(n) is false)) {
                current ~= dependency;
                func(dependency, current);
            }
        }
        string[] result;
        func(root, result);
        return result;
    }

    struct Result {
        string[] librarySearchPathList;
        string[] libraryPathList;
    }

    Result result;

    foreach (p; dependentPackageList(data.rootPackageName)
        .map!(n => data.findPackage(n))
        .filter!(p => p.targetFileName.endsWith(".a"))) {

        result.librarySearchPathList ~= buildPath(p.path, p.targetPath);
        result.libraryPathList ~= p.targetFileName;
    }

    result.librarySearchPathList = result.librarySearchPathList.sort.uniq.array;
    result.libraryPathList = result.libraryPathList.sort.uniq.array;
    return result;
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

private string findPhobosPath() {
    import std.algorithm : map, filter;
    import std.array : front;
    import std.conv : to;
    import std.exception : ifThrown;
    import std.file : exists, write;
    import std.path : buildPath;
    import std.process : execute;
    import std.string : chomp, split;
    import sbylib.editor.project : MetaInfo;

    if (MetaInfo().phobosPath.exists)
        return MetaInfo().phobosPath;

    auto file = sbyDir.buildPath("tmp.d");
    file.write(q{
/+dub.sdl:
dependency "dmd" version="~master"
+/
void main()
{
    import dmd.frontend;
    import std.stdio;
    findImportPaths().writeln;
}
});
    
    auto result = execute(["dub", file]).output
    .split("\n")
    .map!(line => line.to!(string[]).ifThrown([""])[0])
    .filter!(line => line.length > 0)
    .front;
    MetaInfo().phobosPath = result;
    MetaInfo().saveConfig();

    return result;
}
