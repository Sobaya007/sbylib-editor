import sbylib.graphics;
import sbylib.editor;

void entryPoint(Project proj, EventContext context) {
    auto window = proj.get!Window("window");
    with (context()) {
        when((Ctrl + KeyButton.KeyR).pressed).then({
            auto oldTitle = window.title;
            window.title = "reloading...";
            proj.reload();
            window.title = oldTitle;
        });
    }
}

mixin(Register!(entryPoint));
