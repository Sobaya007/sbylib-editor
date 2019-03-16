module sbylib.editor.project.moduleunit;

import std.format : format;

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

    this(Project proj, string file) {
        import std.format : format;
        import sbylib.editor.compiler.compiler : Compiler;
        import sbylib.editor.util : importPath;

        auto dll = Compiler.compile(file, importPath);
        this(proj, dll);
    }

    this(Project proj, DLL dll) {
        auto getFunctionName = dll.loadFunction!(string function())("_functionName");
        auto functionName = getFunctionName();
        this.func = dll.loadFunction!(FuncType)(functionName);
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

enum Register(alias f) = f.mangleof.format!q{ extern(C) string _functionName() { return "%s"; }};
