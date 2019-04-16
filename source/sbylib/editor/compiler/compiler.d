module sbylib.editor.compiler.compiler;

public import sbylib.editor.compiler.dll : DLL;
public import sbylib.graphics.event.event : Event;

class Compiler {
static:

    private uint seed;

    auto compile(string fileName) {
        import std.format : format;
        import std.path : buildPath;
        import sbylib.editor.util : sbyDir;

        const dllName = sbyDir.buildPath(format!"%s%d.so"(fileName, seed++));
        return compileDLL(fileName, dllName); 
    }

    private auto compileDLL(string inputFileName, string outputFileName) {
        import std.algorithm : map, all;
        import std.array : array;
        import std.concurrency : spawn, send, receiveTimeout, Tid, thisTid;
        import std.datetime : msecs, seconds, SysTime, Clock;
        import std.process : execute;
        import std.file : timeLastModified, getSize;
        import std.format : format;
        import std.functional : memoize;
        import std.stdio : writefln;
        import core.thread : Thread;
        import sbylib.graphics : VoidEvent, when, Frame, finish, then;
        import sbylib.editor.project : MetaInfo;
        import sbylib.editor.tools : Dub, DScanner;
        import sbylib.editor.util : importPath, dependentLibraries;

        const dependencies = memoize!dependentLibraries();
        const linkerFlags = dependencies.librarySearchPathList.map!(p =>"-L" ~ p).array
            ~ dependencies.libraryPathList.map!(p => "-l" ~ p).array;

        const command = createCompileCommand(
                inputFileName ~ DScanner.importList(inputFileName),
                outputFileName,
                memoize!importPath,
                linkerFlags);

        spawn(function (immutable(string[]) command, string key,
                    string outputFileName, Tid tid) {
            writefln("Compiling %s", outputFileName);

            auto dmd = execute(command);

            MetaInfo().lastCompileTime[key] = Clock.currTime.toISOString;
            if (dmd.status != 0) {
                send(tid, format!"Compilation failed\n%s"(dmd.output));
                return;
            }
            send(tid, cast(string)null);
        }, command.idup, inputFileName, outputFileName, thisTid);

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

    private string[] createCompileCommand(const(string[]) inputFileList, string outputFile,
            const(string[]) importPathList, const(string[]) linkerFlags) {
        import std.algorithm : map;
        import std.array : array;

        return ["dmd"]
            ~ inputFileList
            ~ ("-of="~ outputFile)
            ~ "-shared"
            ~ importPathList.map!(p => "-I" ~ p).array
            ~ linkerFlags.map!(f => "-L" ~ f).array;
    }
}
