module sbylib.editor.compiler.compiler;

public import sbylib.editor.compiler.dll : DLL;
public import sbylib.graphics.event.event : Event;

import std.datetime : SysTime;

class Compiler {
static:

    private __gshared int[string] seedList;
    private shared int[] compilingCount = new shared int[1];

    void finalize() {
        import std.file : remove, rename, exists;
        foreach (file, seed; seedList) {
            foreach (i; 0..seed) {
                if (getFileName(file,i).exists) remove(getFileName(file, i));
            }
            if (getFileName(file, seed).exists) rename(getFileName(file, seed), getFileName(file, 0));
        }
    }

    private string getFileName(string base, int seed) {
        import std.format : format;
        import sbylib.editor.util : sbyDir;
        return format!"%s/%s%d.so"(sbyDir, base, seed);
    }

    auto compile(string inputFileName) {
        import std : spawn, send, receiveTimeout, receiveOnly, Tid, thisTid, ownerTid,
               to, seconds, msecs, timeLastModified, filter, array, asAbsolutePath, asNormalizedPath;
        import std.functional : memoize;
        import core.thread : Thread;
        import core.atomic : atomicOp;
        import sbylib.graphics : VoidEvent, when, Frame, finish, then;
        import sbylib.editor.project : MetaInfo;
        import sbylib.editor.tools : Dub, DScanner;
        import sbylib.editor.util : importPath, dependentLibraries;

        auto dependencies = memoize!dependentLibraries();
        auto config = immutable CompileConfig(
                inputFileName,
                DScanner.importListRecursive!((string f) => isProjectFile(f))(inputFileName)
                    .filter!((string f) =>
                        f.asAbsolutePath.asNormalizedPath.array != inputFileName.asAbsolutePath.asNormalizedPath.array)
                    .array.idup,
                memoize!importPath.idup,
                dependencies.libraryPathList.idup,
                dependencies.librarySearchPathList.idup);

        struct Result {
            string output;
            string outputFileName;
            Tid tid;
        }

        auto tid = spawn((immutable CompileConfig config, shared int[] compilingCount) {
            while (compilingCount[0] > 3) {
                Thread.sleep(1.seconds);
            }
            compilingCount[0].atomicOp!"+="(1);
            auto r = build(config);
            compilingCount[0].atomicOp!"-="(1);
            while (true) {
                send(ownerTid, Result(r.output, r.outputFileName, thisTid));
                auto success = receiveOnly!bool;
                if (success) break;
            }
        }, config, compilingCount);

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
                    result.fire(new DLL(r.outputFileName));
                } else {
                    result.throwError(new Exception(r.output));
                }
            });
        });
        return result;
    }

    private static auto build(immutable CompileConfig config) {

        import std.concurrency : send, ownerTid;
        import std.format : format;
        import std.file : exists, timeLastModified, remove;
        import std.process : execute;
        import std.stdio : writefln;
        import std.path : baseName, extension;
        import sbylib.editor.util : sbyDir;

        struct Result { string output, outputFileName; }

        const base = config.mainFile.baseName(config.mainFile.extension);
        auto seed = base in seedList ? seedList[base] : (seedList[base] = 0);
        auto outputFileName = getFileName(base, seed);

        if (outputFileName.exists) {
            writefln("Cache found: %s", outputFileName);

            bool useCache = true;
            foreach (dep; config.dependencies) {
                if (dep.timeLastModified > outputFileName.timeLastModified) {
                    writefln("%s has been modified", dep);
                    useCache = false;
                }
            }
            if (useCache) {
                return Result("", outputFileName);
            }
            seed = ++seedList[base];
            outputFileName = getFileName(base, seed);
        }

        writefln("Compiling %s", outputFileName);

        const command = config.createCommand(outputFileName);
        auto dmd = execute(command);

        if (dmd.status != 0) {
            return Result(format!"Compilation failed\n%s"(dmd.output), outputFileName);
        }
        remove(format!"%s/%s%d.o"(sbyDir, base, seed));
        writefln("Compile finished %s\n%s", outputFileName, dmd.output);
        return Result("", outputFileName);
    }

    private static bool isProjectFile(string f) {
        import sbylib.editor.project : MetaInfo;
        import std : absolutePath, dirName, asNormalizedPath, array;

        const projectRoot = MetaInfo().projectName.absolutePath;
        f = f.absolutePath.asNormalizedPath.array;

        while (f != f.dirName) {
            if (f == projectRoot) return true;
            f = f.dirName;
        }
        return false;
    }
}

private struct CompileConfig {
    string   mainFile;
    string[] inputFiles;
    string[] importPath;
    string[] libraryPath;
    string[] librarySearchPath;

    string[] createCommand(string outputFileName) const {
        import std.algorithm : map;
        import std.array : array;

        version (DigitalMars) {
            return ["dmd"]
                ~ "-L=-fuse-ld=gold"
                ~ "-g"
                ~ mainFile
                ~ inputFiles
                ~ ("-of="~ outputFileName)
                ~ "-shared"
                ~ importPath.map!(p => "-I" ~ p).array
                ~ librarySearchPath.map!(f => "-L-L" ~ f).array
                ~ libraryPath.map!(f => "-L-l" ~ f[3..$-2]).array;
        } else version (LDC) {
            return ["dmd"]
                ~ "-g"
                ~ mainFile
                ~ inputFiles
                ~ ("-of="~ outputFileName)
                ~ "-shared"
                ~ importPath.map!(p => "-I" ~ p).array
                ~ librarySearchPath.map!(f => "-L-L" ~ f).array
                ~ libraryPath.map!(f => "-L-l" ~ f[3..$-2]).array;
        } else {
            static assert("This compiler is not supported");
        }
    }

    auto lastModified() const {
        import std.algorithm : map, reduce, max;
        import std.array : array;
        import std.file : timeLastModified;

        return dependencies
            .map!(p => p.timeLastModified)
            .reduce!max;
    }

    auto dependencies() const {
        import std.algorithm : map, filter;
        import std.array : array;
        import std.file : isFile;
        return ([mainFile]
             ~ inputFiles
             ~ importPath
             ~ libraryPath.map!(p => search(p)).array)
            .filter!(p => p.isFile)
            .array;
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
