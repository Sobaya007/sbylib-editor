module sbylib.editor.compiler.dll;

class DLL {

    private void* lib;

    this(string dllname) {
        import std.format : format;
        import std.file : exists;
        import core.runtime : Runtime;
        import core.sys.posix.dlfcn : dlopen;

        assert(dllname.exists);

        this.lib = Runtime.loadLibrary(dllname);
        if (lib is null) throw new Exception(format!"Could not load shared library: %s"(dllname));
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
        if (f is null) throw new Exception(format!"Could not load function '%s' from the shared library"(functionName));

        auto func = cast(FunctionType)f;
        if (func is null) throw new Exception(format!"The type of '%s' is not '%s'"(functionName, FunctionType.stringof));

        return func;
    }

}
