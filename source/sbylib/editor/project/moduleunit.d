module sbylib.editor.project.moduleunit;

import std.format : format;
import std.traits : moduleName;

class Module(RetType) {

    import sbylib.graphics : EventContext, VoidEvent;
    import sbylib.editor.compiler.dll : DLL;
    import sbylib.editor.project.global : Global;
    import sbylib.editor.project.project : Project;
    import std.datetime : SysTime;

    private alias FuncType = RetType function(Project, EventContext);

    private EventContext context;
    private FuncType func;
    private DLL dll;
    private Project proj;
    private string file;
    string name;
    private VoidEvent buildFinish;

    this(Project proj, string file) {
        import std.format : format;
        import sbylib.editor.compiler.compiler : Compiler;
        import sbylib.editor.project.metainfo : MetaInfo;
        import sbylib.graphics : then, error;

        this.file = file;
        this.proj = proj;
        this.context = new EventContext;

        this.buildFinish = new VoidEvent;
        Compiler.compile(file)
        .then((DLL dll) {
            initFromDLL(dll);
            this.buildFinish.fire();
        })
        .error((Exception e) => buildFinish.throwError(e));
    }

    this(Project proj, DLL dll, string file) {
        this.file = file;
        this.proj = proj;
        this.context = new EventContext;
        this.initFromDLL(dll);
    }

    void destroy() {
        this.context.kill();
        //this.dll.unload();
    }

    auto run() {
        import sbylib.graphics : Event, then, error, when, Frame, once;

        static if (is(RetType == void)) {
            alias Result = Event!();
            auto result = new Result;
            alias apply = { func(proj, context); result.fireOnce(); };
        } else {
            alias Result = Event!(RetType);
            auto result = new Result;
            alias apply = { result.fireOnce(func(proj, context)); };
        }
        if (buildFinish is null) {
            when(Frame).then({
                context.bind();
                apply();
            }).once();
        } else {
            buildFinish.then({
                context.bind();
                apply();
            })
            .error((Exception e) => result.throwError(e));
        }
        return result;
    }

    private void initFromDLL(DLL dll) {
        this.dll = dll;

        auto getFunctionName = dll.loadFunction!(string function())(getFunctionNameName(file));
        auto functionName = getFunctionName();
        this.func = dll.loadFunction!(FuncType)(functionName);

        auto getModuleName = dll.loadFunction!(string function())(getModuleNameName(file));
        this.name = getModuleName();
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
