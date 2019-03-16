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

    string interpret(string input) {
        import sbylib.editor.compiler.compiler : Compiler;
        import sbylib.editor.project.moduleunit : Module;
        import sbylib.editor.util : importPath;

        alias SModule = Module!(string);

        auto mod = new SModule(proj, Compiler.compileFromSource(createCode(input), importPath));
        scope (exit) mod.destroy();

        return mod.run();
    }

    auto complete(string input, long cursorPos) {
        import std.string : replace;
        import std.file : write;
        import std.path : buildPath;
        import sbylib.editor.compiler.compiler : Compiler;
        import sbylib.editor.util : importPath, sbyDir;

        auto file = sbyDir.buildPath("test.d");
        file.write(createCode(input));

        return dcd.complete(file, cursorPos + cursorOffset);
    }

    private string createCode(string input) {
        import std.string : replace;

        return createCode().replace("${input}", input);
    }

    private long cursorOffset() {
        import std.algorithm : countUntil;

        auto key = "${input}";
        return createCode().countUntil(key)-1;
    }

    private string createCode() {
        return q{
            import sbylib.editor;
            import sbylib.graphics;

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

            mixin(Register!(func));
        };
    }
}
