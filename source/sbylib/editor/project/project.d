module sbylib.editor.project.project;

public import sbylib.editor.project.global : Global;

class Project {

    import sbylib.editor.project.moduleunit : Module;

    private alias VModule = Module!(void);

    VModule[string] moduleList;

    void delegate(Exception) loadErrorHandler;

    Global global;
    alias global this;

    static void initialize() {
        import sbylib.editor.project.metainfo : MetaInfo;
        auto proj = new Project;
        proj.loadErrorHandler = &proj.defaultErrorHandler;
        proj.load(MetaInfo().rootFile);
    }

    private this() {}

    void addFile(string file) {
        import std.file : exists, mkdirRecurse, copy;
        import std.path : dirName; import sbylib.editor.util : resourcePath;
        import sbylib.editor.project.metainfo : MetaInfo;

        if (file.dirName.exists is false)
            file.dirName.mkdirRecurse();

        resourcePath("template.d").copy(file);

        MetaInfo().projectFileList ~= file;
    }

	auto load() {
        import std.file : dirEntries, SpanMode;
        import sbylib.graphics : IEvent, when, allFinish;
        import sbylib.editor.project.metainfo : MetaInfo;

        IEvent[] eventList;
        foreach (file; MetaInfo().projectFileList) {
            eventList ~= this.load(file);
        }
        return when(eventList.allFinish);
	}

	auto load(string file) {
        import sbylib.graphics : error;

        if (file in moduleList)
            moduleList[file].destroy();

        moduleList[file] = new VModule(this, file);
        return moduleList[file]
            .run()
            .error((Exception e) {
                if (this.loadErrorHandler) {
                    this.loadErrorHandler(e);
                } else {
                    assert(false, e.msg);
                }
            });
	}

    void reload() {
        import std.file : dirEntries, SpanMode;
        import sbylib.editor.project.metainfo : MetaInfo;

        foreach (file; MetaInfo().projectFileList) {
            this.reload(file);
        }
    }

	void reload(string file) 
        in (file in moduleList)
    {
        load(file);
	}

    auto get(T)(string name) {
        return this[name].get!T;
    }

    private void defaultErrorHandler(Exception e) {
        import std.stdio : writeln;
        import std.string : replace;

        auto msg = e.msg;
        msg = msg.replace("Error", "\x1b[31mError\x1b[39m");
        writeln(msg);
    }
}
