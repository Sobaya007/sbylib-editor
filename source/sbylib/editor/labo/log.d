module sbylib.editor.labo.log; 

import sbylib.graphics;
import sbylib.editor.project.project : Project;
import sbylib.editor.labo.interpretor : Interpretor;
import std.typecons : Nullable;

class Log : Entity {

    static Log opCall() {
        static __gshared Log cache;
        if (cache is null)
            cache = new Log;
        return cache;
    }

    mixin ImplPos;
    mixin ImplScale;
    mixin ImplWorldMatrix;
    mixin Material!(LogMaterial);
    mixin ImplUniform;

    Pixel lineHeight;
    private string[] lines = [""];
    private bool shouldUpdate = false;
    private GlyphGeometry geom;


    this() {
        import sbylib.editor.util : fontPath;

        this.geometry = geom = new GlyphGeometry(fontPath("consola.ttf"));
        this.depthTest = true;
        this.depthWrite = false;
        this.blend = true;
        this.lineHeight = 30.pixel;
        this.tex = geom.glyphStore.texture;

        when(this.beforeRender).then({
            update();
        });

        when(Frame).then({
            this.render();
        });
    }

    void writeln(Args...)(Args args) {
        static foreach (arg; args) {
            import std.conv : to;
            this.lines[$-1] ~= arg.to!string;
        }
        this.lines.length += 1;
        if (this.lines.length > 10)
            this.lines = this.lines[$-10..$];

        shouldUpdate = true;
    }

    private void update() {
        import std.algorithm : filter;
        import std.range : walkLength;

        const maxWidth = Window.getCurrentWindow().width;

        auto glyphLines = geom.glyphStore.toGlyph(this.lines, maxWidth);

        renderGlyph(glyphLines);

        this.pixelHeight = lineHeight;
        this.scale.x = this.scale.y;
        this.pixelX = -pixel(Window.getCurrentWindow().width/2);
        this.pixelY = +pixel(Window.getCurrentWindow().height/2);

        this.tex = geom.glyphStore.texture;
    }

    private void renderGlyph(GS)(GS glyphs) {
        import std.algorithm : max;

        geom.clear();

        int x, y, h;
        foreach (gm; glyphs) {
            if (gm.isBreak) {
                y -= h;
                x = h = 0;
            } else {
                auto g = gm.toGlyph;
                renderGlyph(g, x, y);
                x += g.advance;
                h = cast(int)max(h, g.maxHeight);
            }
        }
    }

    private void renderGlyph(Glyph g, int x, int y) {
        auto s = 1.0 / g.maxHeight;
        geom.addCharacter(g.character, vec2(x,y) * s, vec2(g.advance, g.maxHeight) * s);
    }
}

class LogMaterial : Material {
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

private auto toGlyph(GlyphStore store, string[] lines, int maxWidth) {
    int x;
    G[] result;
    foreach (line; lines) {
        foreach (c; line) {
            auto g = store.toGlyph(c);
            if (x + g.advance < maxWidth) result ~= g;
            else result ~= [Break, g];
        }
        result ~= Break;
    }
    return result;
    //import std.array : front, popFront, empty;

    //struct Result {
    //    GlyphStore store;
    //    string[] lines;
    //    int maxWidth;
    //    int x;

    //    G front() {
    //        if (lines.front.empty) {
    //            return Break;
    //        } else {
    //            auto g = store.toGlyph(lines.front.front);
    //            if (x + g.advance < maxWidth) {
    //                return g;
    //            } else {
    //                return Break;
    //            }
    //        }
    //    }

    //    void popFront() {
    //        if (lines.front.empty) {
    //            lines.popFront;
    //            x = 0;
    //        } else {
    //            const g = this.front;
    //            assert(g !is Break);
    //            if (x + g.advance < maxWidth) {
    //                lines.front.popFront;
    //                x += g.advance;
    //            } else {
    //                lines.front.popFront;
    //                x = 0;
    //            }
    //        }
    //    }

    //    bool empty() {
    //        return lines.empty;
    //    }

    //    auto dup() {
    //        return Result(store, lines.dup, maxWidth);
    //    }
    //}
    //return Result(store, lines.dup, maxWidth);
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
