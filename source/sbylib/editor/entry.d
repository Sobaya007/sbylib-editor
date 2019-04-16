module sbylib.editor.entry;

import sbylib.graphics;
import sbylib.wrapper.gl;
import sbylib.wrapper.glfw;
import sbylib.editor.project.metainfo : MetaInfo;
import sbylib.editor.project.project : Project;

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

    while (window.shouldClose == false) {
        FrameEventWatcher.update();
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
