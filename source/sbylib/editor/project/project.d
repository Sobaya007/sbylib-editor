module sbylib.editor.project.project;

public import sbylib.editor.project.global : Global;
import std.file : exists;

class Project {

    import sbylib.editor.project.moduleunit : Module;

    private alias VModule = Module!(void);

    VModule[string] moduleList;

    void delegate(Exception) loadErrorHandler;

    Global global;
    alias global this;

    static void initialize() {
        import std.path : buildPath;
        import sbylib.editor.project.metainfo : MetaInfo;

        auto proj = new Project;
        proj.loadErrorHandler = &proj.defaultErrorHandler;
        auto po = MetaInfo().projectName.buildPath(MetaInfo().rootFile);
        proj.load(po);
    }

    private this() {
        this.refreshPackage();
    }

    void addFile(string file) {
        import std.file : exists, mkdirRecurse, copy;
        import std.path : dirName; 
        import sbylib.editor.util : resourcePath;
        import sbylib.editor.project.metainfo : MetaInfo;

        if (file.dirName.exists is false)
            file.dirName.mkdirRecurse();

        resourcePath("template.d").copy(file);
        this.refreshPackage();
    }

	auto load() {
        import std.file : dirEntries, SpanMode;
        import sbylib.graphics : IEvent, when, allFinish;
        import sbylib.editor.project.metainfo : MetaInfo;

        IEvent[] eventList;
        foreach (file; this.projectFiles) {
            eventList ~= this.load(file);
        }
        return when(eventList.allFinish);
	}

	auto load(string file) 
        in (file.exists, file)
    {
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

        foreach (file; moduleList.keys) {
            this.reload(file);
        }
    }

	auto reload(string file) 
        in (file in moduleList)
    {
        return load(file);
	}

    auto get(T)(string name) {
        if (name !in this) return null;
        return this[name].get!T;
    }

    string[] projectFiles() {
        import std.algorithm : filter, map;
        import std.array : array;
        import std.file : dirEntries, SpanMode, isFile;
        import std.path : baseName, buildPath;
        import sbylib.editor.project.metainfo : MetaInfo;
        import sbylib.editor.project.moduleunit : isModule;

        return MetaInfo().projectName.dirEntries(SpanMode.breadth)
            .filter!(entry => entry.isFile)
            .filter!(entry => entry.baseName != "package.d")
            .filter!(entry => entry != MetaInfo().projectName.buildPath(MetaInfo().rootFile))
            .filter!(entry => entry.isModule)
            .map!(entry => cast(string)entry)
            .array;
    }

    void refreshPackage() {
        import std.algorithm : filter, map;
        import std.array : array, join;
        import std.conv : to;
        import std.file : dirEntries, SpanMode, readText, write, isDir, isFile;
        import std.format : format;
        import std.path : buildPath, extension, stripExtension, baseName, relativePath;
        import std.string : replace;
        import sbylib.editor.project.metainfo : MetaInfo;
        import sbylib.editor.util : resourcePath;

        auto projectName = MetaInfo().projectName;
        foreach (entry; projectName.dirEntries(SpanMode.breadth)) {
            if (entry.isFile) continue;

            const fileName = entry.buildPath("package.d");

            auto dirImportList = entry
                .dirEntries(SpanMode.shallow)
                .filter!(e => e.isDir)
                .map!(e => e.relativePath(projectName))
                .map!(p => p.replace("/", "."))
                .map!(name => name.format!"import %s;")
                .array;
            auto fileImportList = entry
                .dirEntries(SpanMode.shallow)
                .filter!(e => e.isFile)
                .map!(e => e.relativePath(projectName))
                .filter!(p => p.extension == ".d")
                .filter!(p => p.baseName != "package.d")
                .map!(e => e.stripExtension.replace("/", "."))
                .map!(name => name.format!"import %s;")
                .array;

            const moduleName = entry.replace("/", ".");
            const content = resourcePath("package.d").readText
                .replace("${moduleName}", moduleName)
                .replace("${importList}", (dirImportList ~ fileImportList).join("\n"));

            fileName.write(content);
        }
    }

    private void defaultErrorHandler(Exception e) {
        import std.stdio : writeln;
        import std.string : replace;

        auto msg = e.msg;
        msg = msg.replace("Error", "\x1b[31mError\x1b[39m");
        writeln(msg);
    }
}
