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
        import std.conv : to;
        import std.datetime : msecs, seconds, SysTime, Clock;
        import std.process : execute;
        import std.file : timeLastModified, getSize, exists;
        import std.format : format;
        import std.functional : memoize;
        import std.stdio : writefln;
        import core.thread : Thread;
        import sbylib.graphics : VoidEvent, when, Frame, finish, then;
        import sbylib.editor.project : MetaInfo;
        import sbylib.editor.tools : Dub, DScanner;
        import sbylib.editor.util : importPath, dependentLibraries;

        auto dependencies = memoize!dependentLibraries();
        const config = CompileConfig(
                inputFileName,
                DScanner.importList(inputFileName),
                outputFileName,
                memoize!importPath,
                dependencies.libraryPathList,
                dependencies.librarySearchPathList);

        const command = config.createCommand();

        spawn(function (immutable(string[]) command,
                    string outputFileName, immutable SysTime lastModified, Tid tid) {

            if (outputFileName.exists
                    && outputFileName.timeLastModified > lastModified) {
                writefln("Cache found: %s", outputFileName);
                send(tid, cast(string)null);
                return;
            }

            writefln("Compiling %s", outputFileName);

            auto dmd = execute(command);

            import std.stdio : writeln;
            writeln(dmd.output);

            if (dmd.status != 0) {
                send(tid, format!"Compilation failed\n%s"(dmd.output));
                return;
            }
            send(tid, cast(string)null);
        }, command.idup, outputFileName, config.lastModified.to!(immutable SysTime), thisTid);

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

private struct CompileConfig {
    string   mainFile;
    string[] inputFiles;
    string   outputFile;
    string[] importPath;
    string[] libraryPath;
    string[] librarySearchPath;

    string[] createCommand() const {
        import std.algorithm : map;
        import std.array : array;

        return ["dmd"]
            ~ "-L=-fuse-ld=gold"
            ~ mainFile
            ~ inputFiles
            ~ ("-of="~ outputFile)
            ~ "-shared"
            ~ importPath.map!(p => "-I" ~ p).array
            ~ librarySearchPath.map!(f => "-L-L" ~ f).array
            ~ libraryPath.map!(f => "-L-l" ~ f[3..$-2]).array;
    }

    auto lastModified() const {
        import std.algorithm : map, reduce, max;
        import std.array : array;
        import std.file : timeLastModified;

        return ([mainFile]
             ~ inputFiles
             ~ importPath
             ~ libraryPath.map!(p => search(p)).array)
            .map!(p => p.timeLastModified)
            .reduce!max;
    }

    private auto search(string p) const {
        import std.algorithm : map, filter;
        import std.array : front;
        import std.file : exists;
        import std.path : buildPath;

        return librarySearchPath
            .map!(d => d.buildPath(p))
            .filter!(p => p.exists)
            .front;
    }
}
