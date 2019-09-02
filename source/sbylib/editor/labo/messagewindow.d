module sbylib.editor.labo.messagewindow; 

import sbylib.graphics;
import sbylib.editor.project.project : Project;
import sbylib.editor.labo.interpretor : Interpretor;
import sbylib.wrapper.glfw : Window, WindowBuilder, Screen;
import std.typecons : Nullable;

private enum Margin = 50.pixel;

class MessageWindow {

    Window window;
    alias window this;

    private Canvas canvas;
    private Message message;

    this(string _title, string msg) {
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
            window.pos = [0,0];

            this.canvas = CanvasBuilder().build(window);
            this.message = new Message(msg);

            when(mouse.scrolled).then((vec2 scroll) {
                message.pos.y -= scroll.y * 0.06;
                if (message.pos.y < 0) message.pos.y = 0;
            });
        }
    }

    void render() {
        auto current = Window.getCurrentWindow();
        scope(exit) current.makeCurrent();

        window.makeCurrent();
        with (canvas.getContext()) {
            clear(ClearMode.Color, ClearMode.Depth);
            message.render();
        }
    }

    void text(string msg) {
        this.message.update(msg);
    }
}

class Message : Entity {

    mixin ImplPos;
    mixin ImplWorldMatrix;
    mixin Material!(MessageMaterial);
    mixin ImplUniform;

    private Pixel lineHeight;
    private GlyphGeometry geom;

    this(string lines) {
        import sbylib.editor.util : fontPath;

        this.geometry = geom = new GlyphGeometry(fontPath("consola.ttf"));
        this.depthTest = false;
        this.depthWrite = false;
        this.lineHeight = 18.pixel;
        this.tex = geom.glyphStore.texture;

        this.update(lines);
    }

    void update(string text) {
        import std : split, filter, walkLength;

        auto lines = text.split("\n");

        const Pixel maxWidth = Window.getCurrentWindow().width - Margin * 2;

        auto glyphLines = geom.glyphStore.toGlyph(lines, maxWidth, lineHeight);

        renderGlyph(glyphLines);

        this.tex = geom.glyphStore.texture;
    }

    private void renderGlyph(GS)(GS glyphs) {
        import std.algorithm : max;

        geom.clear();

        Pixel x, y, h;
        foreach (gm; glyphs) {
            if (gm.isBreak) {
                y -= h;
                x = 0.pixel;
                h = 0.pixel;
            } else {
                auto g = gm.toGlyph;
                renderGlyph(g, x, y);
                x += g.advance.pixel;
                h = cast(int)max(h, g.maxHeight);
            }
        }
    }

    private void renderGlyph(Glyph g, Pixel x, Pixel y) {
        auto window = Window.getCurrentWindow();
        Pixel h = lineHeight;
        Pixel w = pixel(g.advance * lineHeight / g.maxHeight);
        auto s = 2 / vec2(window.width, window.height);
        geom.addCharacter(g.character,
                (vec2(x+Margin,y-Margin) * lineHeight / g.maxHeight) * s + vec2(-1,+1),
                vec2(w,h) * s);
    }
}

class MessageMaterial : Material {
    mixin VertexShaderSource!(q{
        #version 450
        in vec4 position;
        in vec2 texcoord;
        out vec2 tc;
        uniform mat4 worldMatrix;

        void main() {
            gl_Position = worldMatrix * position;
            tc = texcoord;
        }
    });

    mixin FragmentShaderSource!(q{
        #version 450
        in vec2 tc;
        out vec4 fragColor;
        uniform sampler2D tex;

        void main() {
            fragColor = texelFetch(tex, ivec2(tc), 0).rrrr;
        }
    });
}

private auto toGlyph(GlyphStore store, string[] lines, Pixel maxWidth, Pixel lineHeight) {
    G[] result;
    foreach (line; lines) {
        Pixel x = 0.pixel;
        foreach (c; line) {
            auto g = store.toGlyph(c);
            const Pixel w = g.advance * lineHeight / g.maxHeight;
            if (x + w < maxWidth) {
                result ~= g;
                x += w;
            } else {
                result ~= [Break, g];
                x = w;
            }
        }
        result ~= Break;
    }
    return result;
}

private auto toGlyph(GlyphStore store, dchar c) {
    return G(store.getGlyph(c));
}

private alias G = Nullable!(Glyph);

private Glyph toGlyph(G g) {
    return g.get;
}

private bool isBreak(G g) {
    return g.isNull;
}

private enum Break = G.init;
