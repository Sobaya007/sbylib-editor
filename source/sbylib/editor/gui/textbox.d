module sbylib.editor.gui.textbox;

public import sbylib.editor.gui.item : Item, ImplItem;
public import sbylib.editor.gui.gui : GUI;

import sbylib.graphics;
import std.traits : isSomeString;

class TextBox : Entity, Item {

    mixin ImplPos;
    mixin ImplScale;
    mixin ImplParentalWorldMatrix!(parent);
    mixin Material!(TextBoxMaterial);
    mixin ImplUniform;
    mixin ImplItem;

    private Item parent;
    private dstring text;
    private size_t textCount;
    private GUI root;

    this(String)(GUI root, Item parent, String txt) 
        if (isSomeString!(String))
    {
        import std.conv : to;

        this.root = root;
        this.parent = parent;
        this.geometry = GeometryLibrary().buildPlane();
        this.blend = true;
        this.depthTest = true;
        this.text = txt.to!dstring;
        updateTexture();
    }

    override void appear(ActionSequence builder) {
        this.textCount = 0;
        updateTexture();
        with (builder) {
            enum Animate = false;
            static if (Animate) {
                import std.algorithm : min;
                import std.datetime : Clock;

                auto starttime = Clock.currTime;
                run((resolve) {
                    auto e = when(Frame).run({
                        this.textCount = min(this.text.length, (Clock.currTime - starttime).total!"msecs" / 10);
                        updateTexture();
                    }).until(() => this.textCount == this.text.length);
                    when(e.finish).run({ resolve(); });
                });
            } else {
                run({ 
                    this.textCount = this.text.length;
                    this.updateTexture();
                });
            }

        }
    }

    override void restart(ActionSequence){}

    private void updateTexture() {
        import std.algorithm : map, sum, maxElement;
        import std.string : split;

        auto glyphList = createGlyphList(this.text);
        auto glyphLines = breakLine(glyphList);

        auto canvas = createCanvas(
                glyphLines
                .map!(line => line.map!(g => g.advance.pixel).sum)
                .maxElement,
                pixel(root.lineHeight * glyphLines.length));

        renderGlyph(glyphLines, textCount, canvas);

        this.tex = canvas.color.texture;
        this.pixelWidth =  this.tex.width.pixel;
        this.pixelHeight = this.tex.height.pixel;
    }

    private Glyph[] createGlyphList(dstring txt) {
        auto store = GlyphStore(root.fontPath, root.lineHeight);
        Glyph[] glyphList;
        foreach (c; txt) {
            glyphList ~= store.getGlyph(c);
        }
        return glyphList;
    }

    private Glyph[][] breakLine(Glyph[] glyphList, Pixel maxWidth = Window.getCurrentWindow().width.pixel) {
        Pixel x;
        Glyph[][] result;
        Glyph[] line;
        foreach (g; glyphList) {
            if (g.character == '\n') {
                if (line) {
                    result ~= line;
                    line = null;
                }
                continue;
            }
            if (x + g.advance < maxWidth) {
                line ~= g;
                x += g.advance.pixel;
            } else {
                result ~= line;
                line = null;
                x = 0;
            }
        }
        if (line) result ~= line;
        return result;
    }

    private Canvas createCanvas(Pixel width, Pixel height) {
        Canvas canvas;
        with (CanvasBuilder()) {
            color.enable = true;
            color.clear = Color(0);
            size[0] = width;
            size[1] = height;
            canvas = build();
        }
        with (canvas.getContext()) {
            clear(ClearMode.Color);
        }
        return canvas;
    }

    private void renderGlyph(Glyph[][] glyphList, long cnt, Canvas canvas) {
        import std.algorithm : max;

        long y;
        foreach (line; glyphList) {
            long x, h;
            foreach (g; line) {
                if (cnt-- == 0) return;
                int dstX = cast(int)(x+g.offsetX);
                int dstY = cast(int)(y+g.offsetY);
                renderTexture(canvas, g.texture, dstX, dstY);
                x += g.advance;
                h = max(h, g.maxHeight);
            }
            y += h;
        }
    }

    private void renderTexture(Canvas dst, Texture tex, int x, int y) {
        Canvas srcCanvas;
        with (CanvasBuilder()) {
            size[0] = tex.width;
            size[1] = tex.height;
            color.enable = true;
            color.texture = tex;
            srcCanvas = build();
        }
        dst.render(srcCanvas,
                0, 0, srcCanvas.size[0], srcCanvas.size[1],
                x, y, x+srcCanvas.size[0], y+srcCanvas.size[1],
                TextureFilter.Linear, BufferBit.Color);
    }
}

private class TextBoxMaterial : Material {
    mixin VertexShaderSource!(q{
        #version 450
        in vec4 position;
        in vec2 uv;
        out vec2 uv2;
        uniform mat4 worldMatrix;

        void main() {
            gl_Position = worldMatrix * position;
            uv2 = vec2(uv.x, -uv.y);
        }
    });

    mixin FragmentShaderSource!(q{
        #version 450
        in vec2 uv2;
        out vec4 fragColor;
        uniform sampler2D tex;

        void main() {
            fragColor = texture2D(tex, uv2).rrrr;
        }
    });
}
