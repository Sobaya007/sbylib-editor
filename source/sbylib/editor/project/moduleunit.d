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
    private alias Hash = ubyte[16];

    private EventContext context;
    private FuncType func;
    private DLL dll;
    private Project proj;
    private string file;
    private Hash hash;
    string name;
    private VoidEvent buildFinish;

    this(Project proj, string file) {
        import std.format : format;
        import sbylib.editor.compiler.compiler : Compiler;
        import sbylib.editor.util : importPath;
        import sbylib.editor.project.metainfo : MetaInfo;
        import sbylib.graphics : run, error;

        this.file = file;
        this.proj = proj;
        this.context = new EventContext;
        this.hash = this.createHash(this.file);

        this.buildFinish = new VoidEvent;
        Compiler.compile(MetaInfo().rootFile ~ MetaInfo().projectFileList, importPath)
        .run((DLL dll) {
            initFromDLL(dll);
            this.buildFinish.fire();
        })
        .error((Exception e) => buildFinish.throwError(e));
    }

    this(Project proj, DLL dll, string file) {
        this.file = file;
        this.proj = proj;
        this.context = new EventContext;
        this.hash = this.createHash(this.file);
        this.initFromDLL(dll);
    }

    void destroy() {
        import sbylib.graphics;

        this.context.kill();
        //this.dll.unload();
    }

    bool shouldReload() {
        return this.hash != this.createHash(this.file);
    }

    auto run() {
        import sbylib.graphics : Event, run, error, when, Frame, once;

        static if (is(RetType == void)) {
            alias Result = Event!();
            auto result = new Result;
            alias apply = { func(proj, context); result.fire(); };
        } else {
            alias Result = Event!(RetType);
            auto result = new Result;
            alias apply = { result.fire(func(proj, context)); };
        }
        if (buildFinish is null) {
            when(Frame).run({
                context.bind();
                apply();
            }).once();
        } else {
            buildFinish.run({
                context.bind();
                apply();
            })
            .error((Exception e) => result.throwError(e));
        }
        return result;
    }

    private auto createHash(string file) {
        import std.file : readText;
        import std.digest.md : md5Of;

        return md5Of(readText(file));
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
