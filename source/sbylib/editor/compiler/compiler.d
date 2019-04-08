module sbylib.editor.compiler.compiler;

public import sbylib.editor.compiler.dll : DLL;
public import sbylib.graphics.event.event : Event;

class Compiler {
static:

    private uint seed;

    auto compile(string[] fileNames) {
        import std.format : format;
        import std.path : buildPath;
        import sbylib.editor.util : sbyDir;

        const dllName  = sbyDir.buildPath(format!"test%d.so"(seed++));
        return compileDLL(fileNames, dllName); 
    }

    private auto compileDLL(string[] inputFileNames, string outputFileName) {
        import std.algorithm : map;
        import std.array : array;
        import std.concurrency : spawn, send, receiveTimeout, Tid, thisTid;
        import std.datetime : msecs;
        import std.process : execute;
        import std.format : format;
        import sbylib.graphics : VoidEvent, when, Frame, finish, then;
        import sbylib.editor.util : versions, importPath, linkerFlag;

        auto tid = thisTid;
        auto command = ["dmd"] ~ inputFileNames
                    ~ [format!"-of=%s"(outputFileName), "-shared"]
                    ~ importPath.map!(p => p.format!"-I%s").array
                    ~ linkerFlag
                    ~ versions;
        spawn((immutable(string[]) command, Tid tid) {
            auto dmd = execute(command);
            if (dmd.status != 0)
                send(tid, format!"Compilation failed\n%s"(dmd.output));
            else
                send(tid, cast(string)null);
        }, command.idup, tid);

        auto result = new Event!DLL;
        VoidEvent e;
        e = when(Frame).then({
            receiveTimeout(1.msecs,
                (string output) {
                    e.kill();
                    if (output is null) {
                        result.fire(new DLL(outputFileName));
                    } else {
                        result.throwError(new Exception(output));
                    }
                });
        });
        return result;
    }
}
