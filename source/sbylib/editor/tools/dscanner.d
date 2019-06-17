module sbylib.editor.tools.dscanner;

import std : all, to, exists, Tuple, SysTime;

class DScanner {
static:

    Tuple!(string[], SysTime)[string] importListMemo;

    string[] importListRecursive(alias constraint = (string f) => true)(string file) {
        import std : map, filter, join, sort, uniq, array;

        string[] result = importList(file).filter!(constraint).array;
        while (true) {
            const n = result.length;
            result = (result ~ result.map!(f => importList(f).filter!(constraint)).join).sort.uniq.array;
            if (result.length == n) break;
        }
        return result;
    }

    string[] importList(string file) 
        out (r; r.all!(exists), r.to!string)
    {
        import std : map, filter, join, array, isValidPath, timeLastModified, tuple;
        import sbylib.editor.util : importPath;

        if (auto memo = file in importListMemo) {
            if ((*memo)[1] == file.timeLastModified) {
                return (*memo)[0];
            }
        }

        auto result = execute("-i " ~ file ~ " " ~ importPath.map!(p => "-I" ~ p).join(" "))
            .filter!(line => line.isValidPath)
            .array;

        importListMemo[file] = tuple(result, file.timeLastModified);

        return result;
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
