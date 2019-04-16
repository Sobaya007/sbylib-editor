module sbylib.editor.tools.dub;

class Dub {
static:

    string[] getImportPath() {
        import std.algorithm : map, sort, uniq;
        import std.array : array;
        import std.path : dirName;
        import std.string : split;
        import sbylib.editor.project.metainfo : MetaInfo;

        auto result = describe("--import-paths");
        result ~= MetaInfo().projectFileList
            .map!(file => file.dirName)
            .array
            .sort
            .uniq
            .array;

        return result;
    }

    string[] getVersions() {
        return getData("versions");
    }

    auto describe() {
        import std.array : join;
        import std.json : parseJSON;
        
        return DescribeResult(parseJSON(describe("").join("\n")));
    }

    private string[] getData(string name) {
        return describe("--data=" ~ name);
    }

    private string[] describe(string option) {
        return execute("describe " ~ option);
    }

    private string[] execute(string cmd) {
        import std.algorithm : filter;
        import std.array : split, array;
        import std.process : executeShell;

        const result = executeShell("dub " ~ cmd);
        if (result.status != 0) {
            throw new Exception(result.output);
        }
        return result.output
            .split("\n")
            .filter!(s => s.length > 0)
            .array;
    }
}

struct DescribeResult {
    import std.json : JSONValue;

    private JSONValue content;

    auto root() const {
        return content.object;
    }

    auto packages() const {
        import std.algorithm : map;
        return root["packages"].array
            .map!(p => Package(p));
    }

    auto rootPackageName() const {
        return root["rootPackage"].str;
    }

    auto rootPackage() const {
        return findPackage(rootPackageName);
    }

    auto findPackage(string name) const {
        import std.algorithm : filter;
        import std.array : front;

        return packages
            .filter!(p => p.name == name)
            .front;
    }
}

struct Package {
    import std.json : JSONValue;

    private JSONValue content;

    auto root() const { 
        return content.object; 
    }

    string name() const { 
        return root["name"].str; 
    }

    string path() const {
        return root["path"].str;
    }

    string targetFileName() const {
        return root["targetFileName"].str; 
    }

    string targetPath() const {
        return root["targetPath"].str; 
    }

    auto dependencies() const { 
        import std.algorithm : map;

        return root["dependencies"].array
            .map!(s => s.str);
    }

}
