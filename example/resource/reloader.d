import sbylib.graphics;
import sbylib.editor;

void entryPoint(Project proj, EventContext context) {
    auto window = proj.get!Window("window");
    with (context()) {
        when((Ctrl + KeyButton.KeyR).pressed).run({
            auto oldTitle = window.title;
            window.title = "reloading...";
            proj.load();
            window.title = oldTitle;
        });
    }
}

mixin(Register!(entryPoint));
