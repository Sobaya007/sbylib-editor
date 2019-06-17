module sbylib.editor.labo.messagewindow; 

import sbylib.graphics;
import sbylib.editor.project.project : Project;
import sbylib.editor.labo.interpretor : Interpretor;
import sbylib.wrapper.glfw : Window, WindowBuilder;
import std.typecons : Nullable;

class MessageWindow {

    static opCall(string _title, string msg) {
        auto c = Window.getCurrentWindow();
        assert(c);
        scope(exit) c.makeCurrent();

        with (WindowBuilder()) {
            width = 400.pixel;
            height = 300.pixel;
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

            auto window = buildWindow(c);
            window.makeCurrent();

            auto canvas = CanvasBuilder().build(window);
            auto message = new Message(msg);

            when(Frame).then({
                auto current = Window.getCurrentWindow();
                scope(exit) current.makeCurrent();

                window.makeCurrent();
                with (canvas.getContext()) {
                    clear(ClearMode.Color, ClearMode.Depth);
                    message.render();
                    window.swapBuffers();
                }
            });

            when(mouse.scrolled).then((vec2 scroll) {
                message.pos.y += scroll.y * 0.02;
            });
        }
    }
}

class Message : Entity {

    mixin ImplPos;
    mixin ImplWorldMatrix;
    mixin Material!(MessageMaterial);
    mixin ImplUniform;

    private Pixel lineHeight;
    private string[] lines;
    private GlyphGeometry geom;

    this(string lines) {
        import std : split;
        import sbylib.editor.util : fontPath;

        this.lines = lines.split("\n");
        this.geometry = geom = new GlyphGeometry(fontPath("consola.ttf"));
        this.depthTest = false;
        this.depthWrite = false;
        this.lineHeight = 18.pixel;
        this.tex = geom.glyphStore.texture;

        this.update();
    }

    private void update() {
        import std.algorithm : filter;
        import std.range : walkLength;

        const maxWidth = Window.getCurrentWindow().width;

        auto glyphLines = geom.glyphStore.toGlyph(this.lines, maxWidth, lineHeight);

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
                x = h = 0;
            } else {
                auto g = gm.toGlyph;
                renderGlyph(g, x, y);
                x += g.advance.pixel;
                h = cast(int)max(h, g.maxHeight);
            }
        }
    }

    private void renderGlyph(Glyph g, Pixel x, Pixel y) {
        auto s = 2.0 / Window.getCurrentWindow().height * this.lineHeight / g.maxHeight;
        geom.addCharacter(g.character, vec2(x,y) * s+vec2(-1,+1), vec2(g.advance, g.maxHeight) * s);
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

private auto toGlyph(GlyphStore store, string[] lines, int maxWidth, int lineHeight) {
    G[] result;
    foreach (line; lines) {
        long x;
        foreach (c; line) {
            auto g = store.toGlyph(c);
            const w = 2 * lineHeight * g.advance / g.maxHeight;
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
