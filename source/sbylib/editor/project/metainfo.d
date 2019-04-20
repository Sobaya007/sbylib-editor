module sbylib.editor.project.metainfo;

import dconfig;

class MetaInfo {

    private enum FilePath = ".sbylib/projectfile";

    mixin HandleConfig;

    static opCall() {
        static MetaInfo instance;
        if (instance is null)
            instance = new MetaInfo;
        return instance;
    }

    @config(FilePath) {
        string rootFile;
        string[] projectFileList;
        string phobosPath;
    }

    this() {
        import std.file : exists, mkdirRecurse, write, copy;
        import std.path : dirName;
        import sbylib.editor.util : resourcePath;

        if (FilePath.exists is false) {
            FilePath.dirName.mkdirRecurse();
            saveConfig();
        }

        initializeConfig();

        if (this.rootFile == "") {
            this.rootFile = "resource/root.d";

            if (this.rootFile.dirName.exists is false)
                this.rootFile.dirName.mkdirRecurse();

            copy(resourcePath("root.d"), this.rootFile);
        }
    }
}
