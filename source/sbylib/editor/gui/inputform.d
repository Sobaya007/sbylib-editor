module sbylib.editor.gui.inputform;

public import sbylib.editor.gui.item : Item;
public import sbylib.editor.gui.gui : GUI;

import sbylib.graphics;
import sbylib.editor.gui.blank : Blank;
import sbylib.editor.gui.textbox : TextBox;

class InputForm : Item {

    mixin ImplPos;
    mixin ImplParentalWorldMatrix!(parent);

    private Item parent;
    private Item[] itemList;

    this(Args...)(GUI root, Item parent, Args args) {
        this.parent = parent;

        static foreach (arg; args) {
            import std.traits : isSomeString;

            static if (isSomeString!(typeof(arg))) {
                itemList ~= new TextBox(root, this, arg);
            } else static if (is(typeof(arg) == Blank)) {
                arg.parent = this;
                itemList ~= arg;
            } else {
                static assert(false, "Invalid type");
            }
        }

        this.setAlignment();
    }

    private void setAlignment() {
        import std.algorithm : map, sum;

        const totalWidth = itemList.map!(item => item.pixelWidth).sum;

        Pixel x = -totalWidth/2;
        foreach (item; itemList) {
            x += item.pixelWidth / 2;
            item.pixelX = x;
            x += item.pixelWidth / 2;
        }
    }

    override void appear(ActionSequence builder) {
        foreach (item; itemList)
            item.appear(builder);
    }

    override void restart(ActionSequence builder) {
        foreach (item; itemList)
            item.restart(builder);
    }

    override void render2D() {
        foreach (item; itemList)
            item.render2D();
    }

    override Pixel[2] pixelSize() {
        import std.algorithm : map, sum, maxElement;
        return [
            itemList.map!(item => item.pixelWidth).sum,
            itemList.map!(item => item.pixelHeight).maxElement,
        ];
    }

    override Pixel[2] pixelSize(Pixel[2] size) {
        assert(false);
    }

    mixin ImplPixelWidth;
    mixin ImplPixelHeight;
}
