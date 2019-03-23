module sbylib.editor.gui.blank;

public import sbylib.editor.gui.item : Item, ImplItem;
public import sbylib.editor.gui.gui : GUI;

import sbylib.graphics;

class Blank : Entity, Item, IAction {

    enum Width = 200.pixel;

    mixin ImplPos;
    mixin ImplScale;
    mixin ImplParentalWorldMatrix!(parent);
    mixin Material!(TextBoxMaterial);
    mixin ImplUniform;
    mixin ImplItem;
    mixin ImplAction;

    package Item parent;

    string name;
    string value;
    private int cursorPos;
    private EventContext context;
    private GUI root;

    this(GUI root, string name) {
        this.root = root;
        this.name = name;
        this.context = new EventContext;
        this.geometry = GeometryLibrary().buildPlane();
        this.blend = true;
        this.depthTest = true;
        this.update();

        this.pixelWidth = Width;
        this.pixelHeight = root.lineHeight;
        this.size = vec2(pixelSize);
        this.borderAlpha = 0;
        this.offsetX = 0;

        with (context()) {
            when(Char.typed).run((uint codepoint) {
                import std.conv : to;

                auto c = codepoint.to!char;
                write(c);
            });
            when(KeyButton.Enter.pressed).run({
                this.notifyFinish();
            });
            when(KeyButton.BackSpace.pressed).run({
                backSpace();
            });
            when(KeyButton.Left.pressed).run({
                shift(-1);
            });
            when(KeyButton.Right.pressed).run({
                shift(+1);
            });
        }
    }

    override void appear(ActionSequence builder) {
        with (builder) {
            animate(borderAlpha)
                .to(1)
                .interpolate(Interpolate.SmoothInOut)
                .period(300.msecs);
            restart(builder);
        }
    }

    override void restart(ActionSequence builder) {
        with (builder) {
            action(this);
            run({ context.unbind(); });
            run({ borderAlpha = 0; });
            animate(borderAlpha)
                .to(1)
                .interpolate(function (float t) => sin(t * (360.deg * 3 + 90.deg)) * .5 + .5)
                .period(500.msecs);
            wait(500.msecs);
        }
    }

    private void update() {
        import std.algorithm : map, sum;
        import std.array : array;

        Glyph[] glyphList;
        with (CharTextureBuilder()) {
            font = root.fontPath;
            height = root.lineHeight;

            foreach (i, c; value) {
                character = c;
                glyphList ~= build();
            }
        }

        Canvas dstCanvas;
        with (CanvasBuilder()) {
            color.enable = true;
            color.clear = Color(0);
            size[0] = glyphList.map!(g => g.advance.pixel).sum;
            size[1] = root.lineHeight;
            dstCanvas = build();
        }
        with (dstCanvas.getContext()) {
            clear(ClearMode.Color);
        }

        int x;
        foreach (g; glyphList) {
            int dstX = cast(int)(x+g.offsetX);
            int dstY = cast(int)(g.offsetY);
            renderTexture(dstCanvas, g.texture, dstX, dstY);
            x += g.advance;
        }

        this.tex = dstCanvas.color.texture;
        this.width = cast(float)dstCanvas.size[0] / cast(float)Width;
        auto widthList = glyphList.map!(g => g.texture.width).array;

        this.cursorX = cast(float)widthList[0..cursorPos].sum / widthList.sum;
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

    override void start() {
        context.bind();
    }

    private void write(char c) {
        value = value[0..cursorPos] ~ c ~ value[cursorPos..$];
        cursorPos++;
        update();
    }

    private void backSpace() {
        if (cursorPos == 0) return;
        value = value[0..cursorPos-1] ~ value[cursorPos..$];
        cursorPos--;
        update();
    }

    private void shift(int shift) {
        if (cursorPos + shift < 0) return;
        if (cursorPos + shift > value.length) return;
        cursorPos += shift;
        update();
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
            uv2 = vec2(uv.x, 1-uv.y);
        }
    });

    mixin FragmentShaderSource!(q{
        #version 450
        in vec2 uv2;
        out vec4 fragColor;
        uniform sampler2D tex;
        uniform vec2 size;
        uniform float borderAlpha;
        uniform float offsetX;
        uniform float width;
        uniform float cursorX;

        void main() {
            float uvx = uv2.x / width;
            if (0 < uvx && uvx < 1) {
                fragColor = texture2D(tex, vec2(uvx, uv2.y)).rrrr;
            } else {
                fragColor = vec4(0);
            }
            if (abs(uvx - cursorX) < 2. / size.x) {
                fragColor = vec4(1);
            }

            const float width = 1;

            vec2 coord = uv2 * size;
            coord = min(coord, size - coord);
            if (min(coord.x, coord.y) < width) {
                fragColor = vec4(vec3(1), borderAlpha);
            }
        }
    });
}

