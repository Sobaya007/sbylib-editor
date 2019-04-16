module sbylib.editor.tools.dscanner;

class DScanner {
static:

    string[] importList(string file) {
        import std.algorithm : map, filter;
        import std.array : join, array;
        import std.path : isValidPath;
        import sbylib.editor.util : importPath;

        return execute("-i " ~ file ~ " " ~ importPath.map!(p => "-I" ~ p).join(" "))
            .filter!(line => line.isValidPath)
            .array;
    }

    private string[] execute(string cmd) {
        import std.algorithm : filter;
        import std.array : split, array;
        import std.process : executeShell;

        const result = executeShell("dscanner " ~ cmd);
        if (result.status != 0) {
            throw new Exception(result.output);
        }
        return result.output
            .split("\n")
            .filter!(s => s.length > 0)
            .array;
    }
}
