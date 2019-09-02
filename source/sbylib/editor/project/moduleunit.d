module sbylib.editor.project.moduleunit;

import std : format, moduleName, exists;

// TODO: implement seriously
bool isModule(string file) 
    in (file.exists)
{
    import std : readText, split, map, chomp, filter, startsWith, canFind, empty;
    return readText(file).split("\n")
        .map!(chomp)
        .filter!(line => line.startsWith("//") is false)
        .filter!(line => line.canFind("mixin"))
        .filter!(line => line.canFind("Register"))
        .empty is false;
}

class Module(RetType) {

    import sbylib.graphics : EventContext, VoidEvent;
    import sbylib.editor.compiler.dll : DLL;
    import sbylib.editor.project.global : Global;
    import sbylib.editor.project.project : Project;
    import std.datetime : SysTime;

    private enum State { NotYet, Compling, Success, Fail }

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

        auto getFunctionName = dll.loadFunction!(string function())("getFunctionName");
        auto functionName = getFunctionName();
        this.func = dll.loadFunction!(FuncType)(functionName);

        auto getModuleName = dll.loadFunction!(string function())("getModuleName");
        this.name = getModuleName();
    }
}


enum Register(alias f) = format!q{
    extern(C) string getFunctionName() { return "%s"; }
    extern(C) string getModuleName() { return "%s"; }
}(f.mangleof, moduleName!f);
