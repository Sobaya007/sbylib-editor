module sbylib.editor.labo.dcd; 

import std.process : Pid;

class DCD {

    enum PORT = 8090;

    private Pid server;

    this() {
        import std.algorithm : map;
        import std.array : array;
        import std.format : format;
        import std.process : spawnProcess;
        import std.stdio : stdin, File;
        import sbylib.editor.util : importPath;

        auto portString = PORT.format!"-p%d";
        auto includeStrings = importPath.map!(i => i.format!"-I%s").array;

        this.server = spawnProcess(["dcd-server", portString] ~ includeStrings,
                stdin, File("dcd-stdout.log", "w"), File("dcd-stderror.log", "w"));
    }

    auto complete(string filename, long cursorPos) {
        import std.algorithm : map, filter;
        import std.array : array;
        import std.process : execute;
        import std.format : format;
        import std.string : split, replace;
        import sbylib.editor.util : importPath;

        auto portString = PORT.format!"-p%d";
        auto includeStrings = importPath.map!(i => i.format!"-I%s").array;

        return execute(["dcd-client", portString] ~ includeStrings ~ ["-c", cursorPos.format!"%s", filename])
            .output
            .split("\n")
            .map!(line => line.split("\t"))
            .filter!(words => words.length >= 2)
            .map!(words => words[0])
            .array
            ;
    }

}
