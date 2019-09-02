module sbylib.editor.labo.texturewindow; 

import sbylib.graphics;
import sbylib.editor.project.project : Project;
import sbylib.editor.labo.interpretor : Interpretor;
import sbylib.wrapper.glfw : Window, WindowBuilder, Screen;
import std.typecons : Nullable;

class TextureWindow {

    Window window;
    alias window this;

    private Canvas canvas;
    private TextureEntity entity;

    private enum MaxNum = 4; // for security
    private static int num;

    this(string _title, Texture texture) {

        assert(num < MaxNum);
        num++;

        auto c = Window.getCurrentWindow();
        assert(c);
        scope(exit) c.makeCurrent();

        with (WindowBuilder()) {
            width = 800.pixel;
            height = 600.pixel;
            title = _title;

            defaultHints();
            resizable = false;
            visible = true;
            decorated = true;
            focused = true;
            autoIconify = false;
            floating = true;
            maximized = false;
            doublebuffer = true;
            clientAPI = c.clientAPI;
            contextVersionMajor = c.contextVersionMajor;
            contextVersionMinor = c.contextVersionMinor;
            contextRevision = c.contextRevision;
            profile = c.profile;

            this.window = buildWindow(c);
            window.makeCurrent();

            this.canvas = CanvasBuilder().build(window);
            this.entity = new TextureEntity(texture);
        }
    }

    ~this() {
        num--;
    }

    void render() {
        auto current = Window.getCurrentWindow();
        scope(exit) current.makeCurrent();

        window.makeCurrent();
        with (canvas.getContext()) {
            clear(ClearMode.Color, ClearMode.Depth);
            entity.render();
        }
    }

    static void show(string title, Texture texture) {
        auto window = new TextureWindow(title, texture);
        auto canvas = CanvasBuilder().build(window);
        auto e = when(Frame).then({
            auto pre = Window.getCurrentWindow();
            scope (exit) pre.makeCurrent();
            window.makeCurrent();
            with (canvas.getContext()) {
                clear(ClearMode.Color, ClearMode.Depth);
                window.render();
                window.swapBuffers();
            }
        }).until(() => window.shouldClose);
        when(e.finish).then({
            window.destroy();
            canvas.destroy();
        });
    }
}

class TextureEntity : Entity {
    mixin Material!(TextureMaterial);
    mixin ImplUniform;

    this(Texture texture) {
        this.tex = texture;
        this.geometry = GeometryLibrary().buildPlane();
    }
}

class TextureMaterial : Material {
    mixin VertexShaderSource!(q{
        #version 450
        in vec4 position;
        out vec2 uv;

        void main() {
            gl_Position = vec4(position.xy * 2, 0, 1);
            uv = position.xy + .5;
        }
    });

    mixin FragmentShaderSource!(q{
        #version 450
        in vec2 uv;
        out vec4 fragColor;
        uniform sampler2D tex;

        void main() {
            fragColor = texture2D(tex, uv);
        }
    });
}
