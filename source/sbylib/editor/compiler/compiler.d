module sbylib.editor.compiler.compiler;

public import sbylib.editor.compiler.dll : DLL;
public import sbylib.graphics.event.event : Event;

import std.datetime : SysTime;

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
        import std.concurrency : spawn, send, receiveTimeout, receiveOnly, Tid, thisTid, ownerTid;
        import std.conv : to;
        import std.datetime : seconds, msecs;
        import std.file : timeLastModified;
        import std.functional : memoize;
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

        struct Result {
            string output;
            Tid tid;
        }

        auto tid = spawn((immutable(string[]) command, string outputFileName, immutable SysTime lastModified) {
            auto output = build(command, outputFileName, lastModified);
            while (true) {
                send(ownerTid, Result(output, thisTid));
                auto success = receiveOnly!bool;
                if (success) break;
            }
        }, command.idup, outputFileName, config.lastModified.to!(immutable SysTime));

        auto result = new Event!DLL;
        VoidEvent e;
        e = when(Frame).then({
            receiveTimeout(1.msecs, (Result r) {
                if (tid != r.tid) {
                    send(tid, false);
                    return;
                }
                send(tid, true);
                e.kill();
                if (r.output == "") {
                    result.fire(new DLL(outputFileName));
                } else {
                    result.throwError(new Exception(r.output));
                }
            });
        });
        return result;
    }

    private static string build(immutable(string[]) command, string outputFileName,
            immutable SysTime lastModified) {

        import std.concurrency : send, ownerTid;
        import std.format : format;
        import std.file : exists, timeLastModified;
        import std.process : execute;
        import std.stdio : writefln;

        if (outputFileName.exists
                && outputFileName.timeLastModified > lastModified) {
            writefln("Cache found: %s", outputFileName);
            return "";
        }

        writefln("Compiling %s", outputFileName);

        auto dmd = execute(command);

        writefln("Compile finished\n%s", dmd.output);

        if (dmd.status != 0) {
            return format!"Compilation failed\n%s"(dmd.output);
        }
        return "";
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
