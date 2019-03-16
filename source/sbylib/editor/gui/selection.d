module sbylib.editor.gui.selection;

public import sbylib.editor.gui.item : Item, ImplItem;
public import sbylib.editor.gui.gui : GUI;

import sbylib.graphics;

class Selection : Entity, Item {

    mixin ImplPos;
    mixin ImplScale;
    mixin ImplParentalWorldMatrix!(parent);
    mixin Material!(TextBoxMaterial);
    mixin ImplUniform;
    mixin ImplItem;

    package Item parent;

    string value;
    void delegate() f;
    private EventContext context;
    private ActionSequence builder;
    private GUI root;

    this(GUI root, string value) {
        this(root, value, {});
    }

    this(GUI root, string value, void delegate() f) {
        this.root = root;
        this.value = value;
        this.f = f;
        this.context = new EventContext;
        this.geometry = GeometryLibrary().buildPlane();
        this.blend = true;
        this.depthTest = true;
        this.update();

        this.size = vec2(pixelSize);
        this.borderRate = 0;
        this.borderAlpha = 1;
    }

    override void appear(ActionSequence builder) {}
    override void restart(ActionSequence builder) {}

    void focus(bool focused) {
        with (ActionSequence()) {
            animate(borderRate)
                .to(focused ? 1 : 0)
                .interpolate(Interpolate.SmoothInOut)
                .period(300.msecs);
            start();
        }
    }

    auto select() {
        auto sequence = ActionSequence();
        with (sequence) {
            run({ borderAlpha = 0; });
            animate(borderAlpha)
                .to(1)
                .interpolate(function (float t) => sin(t * (360.deg * 3 + 90.deg)) * .5 + .5)
                .period(500.msecs);
            wait(500.msecs);
            start();
        }
        return sequence;
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
        this.pixelWidth = this.tex.width.pixel;
        this.pixelHeight = this.tex.height.pixel;
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
        uniform float borderRate;

        void main() {
            fragColor = texture2D(tex, uv2).rrrr;
            const float width = 2;

            vec2 coord = uv2 * size;
            coord = min(coord, size - coord);
            if (min(coord.x, coord.y) < width) {
                float angle = atan(uv2.y - 0.5, uv2.x - 0.5);
                if (angle / (2 * 3.1415) + 0.5 < borderRate)
                    fragColor = vec4(borderAlpha);
            }
        }
    });
}

