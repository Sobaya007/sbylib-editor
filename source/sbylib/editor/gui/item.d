module sbylib.editor.gui.item;

public import sbylib.graphics : Pixel, ActionSequence;
public import sbylib.math : mat4;

interface Item {
    Pixel[2] pixelPos();
    Pixel[2] pixelPos(Pixel[2]);
    Pixel pixelX(Pixel);
    Pixel pixelX();
    Pixel pixelY(Pixel);
    Pixel pixelY();
    Pixel[2] pixelSize();
    Pixel[2] pixelSize(Pixel[2]);
    Pixel pixelWidth(Pixel);
    Pixel pixelWidth();
    Pixel pixelHeight(Pixel);
    Pixel pixelHeight();

    mat4 worldMatrix();
    void render2D();
    void appear(ActionSequence);
    void restart(ActionSequence);
}

mixin template ImplItem() {

    override void render2D() {
        this.render();
    }
}
