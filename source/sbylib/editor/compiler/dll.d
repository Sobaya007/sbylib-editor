module sbylib.editor.compiler.dll;

class DLL {

    private void* lib;
    private string dllname;

    this(string dllname) {
        import std.format : format;
        import std.file : exists, getSize;
        import core.runtime : Runtime;
        import core.thread : Thread, seconds;

        this.dllname = dllname;

        if (dllname.exists is false)
            throw new Exception(format!"Shared library '%s' does not exist"(dllname));

        while (dllname.getSize() == 0) {
            import std.stdio : writeln;
            writeln("zzz...");
            Thread.sleep(1.seconds);
        }

        this.lib = Runtime.loadLibrary(dllname);
        if (lib is null) {
            version (Posix) {
                import core.sys.posix.dlfcn : dlerror;
                import std.string : fromStringz;
                throw new Exception(dlerror().fromStringz.format!"Could not load shared library:%s");
            } else {
                throw new Exception(format!"Could not load shared library: %s"(dllname));
            }
        }
    }

    void unload() {
        import core.runtime : Runtime;
        Runtime.unloadLibrary(this.lib);
    }

    auto loadFunction(FunctionType)(string functionName) {
        import std.format : format;
        import std.string : toStringz;
        import core.sys.posix.dlfcn : dlsym;

        const f = dlsym(lib, functionName.toStringz);
        if (f is null) throw new Exception(format!"Could not load function '%s' from %s"(functionName, dllname));

        auto func = cast(FunctionType)f;
        if (func is null) throw new Exception(format!"The type of '%s' is not '%s'"(functionName, FunctionType.stringof));

        return func;
    }

}
