module sbylib.editor.entry;

import core.exception : AssertError;
import sbylib.graphics;
import sbylib.wrapper.gl;
import sbylib.wrapper.glfw;
import sbylib.editor.project.metainfo : MetaInfo;
import sbylib.editor.project.project : Project;
import sbylib.editor.compiler.compiler : Compiler;
import sbylib.editor.labo.messagewindow : MessageWindow;

void startEditor() {

    Window window;
    with (WindowBuilder()) {
        width = 800.pixel;
        height = 600.pixel;
        contextVersionMajor = 4;
        contextVersionMinor = 5;
        floating = true;
        window = buildWindow();
    }
    scope(exit) window.destroy();
    window.makeCurrent();
    
    GL.initialize();

    auto meta = MetaInfo();
    scope(exit) meta.saveConfig();

    Project.initialize();
    scope (exit) Compiler.finalize();

    while (window.shouldClose == false) {
        try {
            FrameEventWatcher.update();
        } catch (AssertError e) {
            import std : writeln;
            writeln(e.toString());
            auto mWindow = new MessageWindow("Error", e.toString());
            scope (exit) mWindow.destroy();

            while (mWindow.shouldClose == false) {
                mWindow.render();
                GLFW.pollEvents();
                mWindow.swapBuffers();
            }
        }
        GLFW.pollEvents();
        window.swapBuffers();
    }
}

void createProjectWizard() {
    //import sbylib.editor.project.project : newProject;
    import sbylib.editor.gui.gui : GUI;

    with (GUI()) {
        text("Type your project name");
        inputForm("Name: ", blank("projectName"));
        text("OK?");
        question([
            selection("Yes"),
            selection("No",  { back(2); })
        ]);
        //run({ newProject(get("projectName")); });

        start();
    }
}
