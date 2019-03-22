module sbylib.editor.project.moduleunit;

import std.format : format;
import std.traits : moduleName;

class Module(RetType) {

    import sbylib.graphics : EventContext;
    import sbylib.editor.compiler.dll : DLL;
    import sbylib.editor.project.global : Global;
    import sbylib.editor.project.project : Project;

    private alias FuncType = RetType function(Project, EventContext);

    private EventContext context;
    private FuncType func;
    private DLL dll;
    private Project proj;
    string name;

    this(Project proj, string file) {
        import std.format : format;
        import sbylib.editor.compiler.compiler : Compiler;
        import sbylib.editor.util : importPath;

        auto dll = Compiler.compile(file, importPath);
        this(proj, dll, file);
    }

    this(Project proj, DLL dll, string file) {
        import std.format : format;

        auto getFunctionName = dll.loadFunction!(string function())(getFunctionNameName(file));
        auto functionName = getFunctionName();
        this.func = dll.loadFunction!(FuncType)(functionName);

        auto getModuleName = dll.loadFunction!(string function())(getModuleNameName(file));
        this.name = getModuleName();

        this.dll = dll;
        this.proj = proj;
        this.context = new EventContext;
    }

    void destroy() {
        import sbylib.graphics;

        this.context.kill();
        //this.dll.unload();
    }

    auto run() {
        scope(exit) context.bind();
        return func(proj, context);
    }

}

enum Register(alias f, string n = __FILE__) = format!q{
    extern(C) string %s() { return "%s"; }
    extern(C) string %s() { return "%s"; }
}(getFunctionNameName(n), f.mangleof, getModuleNameName(n), moduleName!f);

private string getFunctionNameName(string n) {
    return format!"_functionName%s"(convFileName(n));
}

private string getModuleNameName(string n) {
    import std.string : replace;
    return format!"_moduleName%s"(convFileName(n));
}

private string convFileName(string n) {
    import std.string : replace;

    return n.replace("/", "_").replace(".", "_");
}
