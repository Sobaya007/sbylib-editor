module sbylib.editor.project.metainfo;

import dconfig;

class MetaInfo {

    private enum FilePath = "project.json";

    mixin HandleConfig;

    static opCall() {
        static MetaInfo instance;
        if (instance is null)
            instance = new MetaInfo;
        return instance;
    }

    @config(FilePath) {
        string projectName;
        string rootFile;
        string phobosPath;
    }

    this() {
        import std.file : exists, mkdirRecurse, write, copy, isFile, isDir;
        import std.format : format;
        import std.path : dirName, buildPath;
        import sbylib.editor.util : resourcePath;

        if (FilePath.exists is false) {
            FilePath.dirName.mkdirRecurse();
            saveConfig();
        }

        initializeConfig();

        if (this.projectName == "") 
            this.projectName = "project";

        if (this.projectName.exists is false)
            this.projectName.mkdirRecurse();

        if (this.projectName.isDir is false)
            throw new Exception(format!"%s is not a directory"(this.projectName));
        if (this.rootFile == "")
            this.rootFile = "root.d";

        const root = this.projectName.buildPath(this.rootFile);

        if (root.dirName.exists is false)
            root.dirName.mkdirRecurse();

        if (root.exists && root.isFile is false)
            throw new Exception(format!"%s is not a file"(root));

        if (root.exists is false)
            copy(resourcePath("root.d"), root);
    }
}
