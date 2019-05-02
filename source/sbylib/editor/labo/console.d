module sbylib.editor.labo.console; 

import sbylib.graphics;
import sbylib.editor.project.project : Project;
import sbylib.editor.labo.interpretor : Interpretor;

class Console : Entity {

    mixin ImplPos;
    mixin ImplScale;
    mixin ImplWorldMatrix;
    mixin Material!(ConsoleMaterial);
    mixin ImplUniform;

    private string[] lines;
    private string input;
    private long cursorPos;
    private string[] history;
    private long historyPos;
    private Interpretor interpretor;
    private bool writable = true;
    string fontPath;

    this(Project proj) {
        import sbylib.editor.util : fontPath;

        this.fontPath = fontPath("consola.ttf");
        this.interpretor = new Interpretor(proj);
        this.geometry = GeometryLibrary().buildPlane();
        this.blend = true;
        this.depthTest = true;
        this.depthWrite = false;
        this.lineHeight = 30.pixel;
        updateTexture();

        when(this.beforeRender).then({
            auto window = Window.getCurrentWindow();
            this.pixelWidth = this.width.pixel;
            this.pixelHeight = this.height.pixel;
            this.pixelY = pixel(-window.height/2) + this.pixelHeight/2;
        });
    }

    void write(string text) {
        if (writable is false) return;
        input = input[0..cursorPos] ~ text ~ input[cursorPos..$];
        cursorPos += text.length;
        updateTexture();
    }

    void backSpace() {
        if (cursorPos == 0) return;
        input = input[0..cursorPos-1] ~ input[cursorPos..$];
        cursorPos--;
        updateTexture();
    }

    void shift(int shift) {
        if (cursorPos + shift < 0) return;
        if (cursorPos + shift > input.length) return;
        cursorPos += shift;
        updateTexture();
    }

    void complete() {
        import std.algorithm : countUntil;
        import std.conv : to;
        import std.string : join;
        import sbylib.editor;

        if (writable is false) return;

        auto candidates = interpretor.complete(input, cursorPos);

        if (candidates.length == 0) return;

        long lastDot = -1;
        while (true) {
            auto pos = input[lastDot+1..$].countUntil(".")+1;
            if (pos <= 0) break;
            lastDot += pos;
        }

        this.input = this.input[0..lastDot+1];
        this.input ~= candidates[0];
        cursorPos = this.input.length;
        updateTexture();

        with (GUI()) {
            lineHeight = 18.pixel;
            text(candidates.join("\n"));
            waitKey();
            start();
        }
        
    }

    void interpret() {
        import sbylib.editor.labo.interpretor : Interpretor;
        import std.algorithm : max;
        import std.conv : to;
        import std.string : split, replace;

        if (input.length == 0) return;

        history ~= input;
        historyPos = history.length;

        auto input = this.input;
        this.lines ~= ">"~input;
        this.lines ~= "processing...";
        this.input = "";
        this.cursorPos = 0;
        this.writable = false;
        updateTexture();

        alias f = (string output) {
            this.lines = this.lines[0..$-1];
            this.lines ~= output.replace("\t", "   ").split("\n");
            this.writable = true;
            updateTexture();
        };

        interpretor.interpret(input)
            .then((string output) => f(output))
            .error((Exception e) => f(e.msg));
    }

    void shiftHistory(int shift) {
        if (writable is false) return;
        if (historyPos + shift < 0) return;
        if (historyPos + shift > history.length) return;
        historyPos += shift;
        selectHistory();
    }

    private void selectHistory() {
        this.input = (historyPos == history.length ? "" : history[historyPos]);
        cursorPos = input.length;
        updateTexture();
    }

    private void updateTexture() {
        import std.algorithm : map, sum, max;
        import std.array : array;
        import std.conv : to;

        const windowWidth = Window.getCurrentWindow().width;

        auto store = GlyphStore(this.fontPath, this.lineHeight.pixel);
        Glyph[][] glyphLines;
        void handleLine(string line) {
            Glyph[] glyphLine;
            foreach (c; line) {
                glyphLine ~= store.getGlyph(c);
            }
            glyphLines ~= glyphLine;
        }
        foreach (line; this.lines) handleLine(line);
        handleLine(">" ~ input);

        Glyph[][] glyphLines2;
        foreach (line; glyphLines) {
            Glyph[][] glyphLine = [[]];
            int w = 0;
            foreach (g; line) {
                w += g.advance;
                if (w < windowWidth) {
                    glyphLine[$-1] ~= g;
                } else {
                    glyphLine ~= [g];
                    w = cast(int)g.advance;
                }
            }
            glyphLines2 ~= glyphLine;
        }
        const maxLines = Window.getCurrentWindow().height / this.lineHeight.pixel;
        auto begin = max(0, cast(long)glyphLines2.length - maxLines);
        glyphLines2 = glyphLines2[begin..$];

        Canvas dstCanvas;
        with (CanvasBuilder()) {
            color.enable = true;
            color.clear = Color(0);

            size[0] = windowWidth;
            size[1] = this.lineHeight.pixel * cast(int)glyphLines2.length;
            dstCanvas = build();
        }

        auto cnt = glyphLines2.map!(line => line.length).sum + cursorPos - input.length - 1;
        foreach (yIndex, line; glyphLines2) {
            const y = cast(int)(yIndex) * this.lineHeight;
            int x;
            foreach (g; line) {
                Canvas srcCanvas;
                with (CanvasBuilder()) {
                    size[0] = cast(int)g.width;
                    size[1] = cast(int)g.height;
                    color.enable = true;
                    color.texture = g.texture;
                    srcCanvas = build();
                }
                int dstX = cast(int)(x+g.offsetX);
                int dstY = cast(int)(y+g.offsetY);
                dstCanvas.render(srcCanvas,
                        0, 0, srcCanvas.size[0], srcCanvas.size[1],
                        dstX, dstY, cast(int)(dstX+g.width), cast(int)(dstY+g.height),
                        TextureFilter.Linear, BufferBit.Color);

                x += g.advance;

                if (cnt-- == 0) {
                    this.cursorX = x;
                    this.cursorY = y;
                }
            }
        }

        if (tex) tex.destroy();
        tex = dstCanvas.color.texture;

        this.width = pixel(windowWidth);
        this.height = pixel(glyphLines2.length * this.lineHeight);

    }
}

class ConsoleMaterial : Material {
    mixin VertexShaderSource!(q{
        #version 450
        in vec4 position;
        in vec2 uv;
        out vec2 uv2;
        uniform mat4 worldMatrix;

        void main() {
            vec4 p = worldMatrix * position;
            gl_Position = p;
            uv2 = vec2(uv.x, 1-uv.y);
        }
    });

    mixin FragmentShaderSource!(q{
        #version 450
        in vec2 uv2;
        out vec4 fragColor;
        uniform sampler2D tex;
        uniform float cursorX;
        uniform float cursorY;
        uniform float lineHeight;
        uniform float width;
        uniform float height;

        void main() {
            fragColor = texture2D(tex, uv2).rrrr + vec4(vec3(0), 0.3);

            vec2 pixelPos = uv2 * vec2(width, height);
            if (abs(pixelPos.x - cursorX) < 1. && abs(pixelPos.y - (cursorY + lineHeight/2)) < lineHeight/2) {
                fragColor = vec4(1);
            }
        }
    });
}
