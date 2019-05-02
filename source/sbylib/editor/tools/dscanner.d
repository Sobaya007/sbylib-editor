module sbylib.editor.tools.dscanner;

import std.algorithm : all;
import std.conv : to;
import std.file : exists;

class DScanner {
static:

    string[] importList(string file) 
        out (r; r.all!(exists), r.to!string)
    {
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
