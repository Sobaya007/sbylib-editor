module sbylib.editor.gui.background;

public import sbylib.editor.gui.item : Item, ImplItem;
public import sbylib.editor.gui.gui : GUI;

import sbylib.graphics;

class Background : Entity, Item {

    mixin ImplPos;
    mixin ImplScale;
    mixin ImplParentalWorldMatrix!(parent);
    mixin Material!(BackgroundMaterial);
    mixin ImplUniform;
    mixin ImplItem;

    package Item parent;

    private EventContext context;
    private GUI root;
    private Color arrivalColor;

    this(GUI root, Item parent, Color color) {
        this.root = root;
        this.parent = parent;
        this.color = vec4(0);
        this.arrivalColor = color;
        this.context = new EventContext;
        this.geometry = GeometryLibrary().buildPlane();
        this.blend = true;
        this.depthTest = true;
        this.depthWrite = false;

        with (context()) {
            when(this.beforeRender).then({
                this.pixelSize = parent.pixelSize;
            });
        }
    }

    override void appear(ActionSequence builder) {
        with (builder) {
            run({ this.context.bind(); });
            animate(color)
                .to(arrivalColor)
                .interpolate(Interpolate.SmoothInOut)
                .period(300.msecs);
        }
    }

    override void restart(ActionSequence builder) {}
}

private class BackgroundMaterial : Material {
    mixin VertexShaderSource!(q{
        #version 450
        in vec4 position;
        uniform mat4 worldMatrix;

        void main() {
            gl_Position = worldMatrix * position;
        }
    });

    mixin FragmentShaderSource!(q{
        #version 450
        out vec4 fragColor;
        uniform vec4 color;

        void main() {
            fragColor = color;
        }
    });
}

