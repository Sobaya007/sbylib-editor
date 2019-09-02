module sbylib.editor.labo.interpretor;

import sbylib.graphics;
import sbylib.editor.project.project : Project;
import sbylib.editor.labo.dcd : DCD;

class Interpretor {

    private Project proj;
    private DCD dcd;

    this(Project proj) {
        this.proj = proj;
        this.dcd = new DCD;
    }

    auto interpret(string input) {
        import sbylib.editor.compiler.compiler : Compiler;
        import sbylib.editor.compiler.dll : DLL;
        import sbylib.editor.project.moduleunit : Module;
        import sbylib.editor.util : sbyDir;
        import std.file : write;
        import std.path : buildPath;

        alias SModule = Module!(string);

        auto result = new Event!string;

        auto fileName = sbyDir.buildPath("test.d");
        try {
            fileName.write(createCode(input));
        } catch (Exception e) {
            when(Frame).then({ result.fireOnce(e.msg); }).once;
            return result;
        }

        Compiler.compile(fileName)
        .then((DLL dll) {
            auto mod = new SModule(proj, dll, fileName);
            auto proc = mod.run()
            .then((string output) {
                result.fireOnce(output);
            });
            when(proc.finish).then({ mod.destroy(); });
        })
        .error((Exception e) => result.throwError(e));
        return result;
    }

    auto complete(string input, long cursorPos) {
        import std.string : replace;
        import std.file : write;
        import std.path : buildPath;
        import sbylib.editor.compiler.compiler : Compiler;
        import sbylib.editor.util : importPath, sbyDir;

        auto file = sbyDir.buildPath("test.d");
        file.write(createCode(input));

        return dcd.complete(file, cursorPos + cursorOffset + 1);
    }

    private string createCode(string input) {
        import std.algorithm : map;
        import std.array : array;
        import std.format : format;
        import std.regex : matchAll, ctRegex;
        import std.string : replace, split;

        auto variableList = input
            .matchAll(ctRegex!`\$\{(.*?)\}`)
            .map!(m => m.hit)
            .array;

        foreach (v; variableList) {
            auto name = v[2..$-1]; // "${name}"[2..$-1] == "name"
            if (name !in proj)
                throw new Exception(format!`"%s" is not defined.`(v));
            auto type = proj[name].type.toString.split(".")[$-1];
            input = input.replace(v, format!`project.get!(%s)("%s")`(type, name));
        }

        return createCode().replace("${input}", input);
    }

    private long cursorOffset() {
        import std.algorithm : countUntil;

        auto key = "${input}";
        return createCode().countUntil(key)-1;
    }

    private string createCode() {
        import std.algorithm : map, filter;
        import std.array : join;
        import std.string : replace;
        import std.format : format;

        return q{
            import sbylib.editor;
            import sbylib.graphics;
            ${import}

            mixin(Register!(func));

            string func(Project project, EventContext context) {
                import std.conv : to;
                with (project) {
                    static if (is(typeof((${input}).to!string))) {
                        return (${input}).to!string;
                    } else {
                        ${input};
                        return "";
                    }
                }
            }
        }.replace("${import}",
            proj.moduleList.values
            .map!(m => format!`import %s;`(m.name)).join("\n"));
    }
}
