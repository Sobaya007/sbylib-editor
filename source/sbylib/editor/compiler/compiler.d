module sbylib.editor.compiler.compiler;

public import sbylib.editor.compiler.dll : DLL;

class Compiler {
static:

    private uint seed;

    DLL compile(string fileName, string[] importPath = []) {
        import std.format : format;
        import std.path : buildPath;
        import sbylib.editor.util : sbyDir;

        const dllName  = sbyDir.buildPath(format!"test%d.so"(seed++));
        compileDLL(fileName, dllName, importPath); return new DLL(dllName);
    }

    private void compileDLL(string inputFileName, string outputFileName, string[] importPathList) {
        import std.algorithm : map;
        import std.array : array;
        import std.process : execute;
        import std.format : format;
        import sbylib.editor.util : versions;

        const dmd = execute(["dmd", inputFileName,
                format!"-of=%s"(outputFileName), "-shared"]
                ~ importPathList.map!(p => p.format!"-I%s").array
                ~ versions);

        if (dmd.status != 0) throw new Exception(format!"Compilation failed\n%s"(dmd.output));
    }
}
