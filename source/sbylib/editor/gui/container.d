module sbylib.editor.gui.container;

public import sbylib.editor.gui.item : Item;
public import sbylib.editor.gui.gui : GUI;

import sbylib.graphics;

class Container : Item {

    private enum Margin = 20.pixel;

    mixin ImplWorldMatrix;
    mixin ImplPixelX;
    mixin ImplPixelY;
    mixin ImplPixelWidth;
    mixin ImplPixelHeight;

    Item[] itemList;
    private GUI root;
    
    this(GUI root) {
        this.root = root;
    }

    IAction append(Item newItem) {
        auto result = ActionSequence();
        with (result) {
            run((resolve) {
                this.itemList ~= newItem;
                setAlignment(resolve);
            });
            newItem.appear(result);
            return result;
        }
    }

    IAction popBack(int num) 
        in (itemList.length > 0)
    {
        return new RunAction((resolve) {
            this.itemList = this.itemList[0..$-num];
            setAlignment(resolve);
        });
    }

    private void setAlignment(void delegate() resolve) {
        import std.algorithm : map, filter, sum, reduce, count;
        import sbylib.editor.gui.background : Background;

        auto itemList = this.itemList
            .filter!(item => cast(Background)item is null);
        auto cnt = itemList.count;

        if (cnt == 0) {
            resolve();
            return;
        }

        Pixel y = this.pixelHeight/2;
        foreach (item; itemList) {
            y -= item.pixelHeight / 2;
            with (ActionSequence()) {
                animate!"pixelY"(item)
                .to(y)
                .interpolate(Interpolate.SmoothInOut)
                .period(200.msecs);

                when(finish).run({
                    cnt--;
                    if (cnt == 0) resolve();
                });
                start();
            }
            y -= item.pixelHeight / 2 + Margin;
        }
    }

    override void render2D() {
        foreach (item; this.itemList) item.render2D();
    }

    override void appear(ActionSequence) {}
    override void restart(ActionSequence) {}

    Pixel[2] pixelPos() { assert(false); }
    Pixel[2] pixelPos(Pixel[2]) { assert(false); }

    Pixel[2] pixelSize() {
        import std.algorithm : map, filter, sum, maxElement, count;
        import std.array : empty;
        import sbylib.editor.gui.background : Background;

        auto itemList = this.itemList
            .filter!(item => cast(Background)item is null);

        if (itemList.empty) return [0.pixel, 0.pixel];

        const width = itemList
            .map!(item => item.pixelWidth)
            .maxElement;

        const height = itemList
            .map!(item => item.pixelHeight).sum
            + (itemList.count-1) * Margin;

        return [width.pixel, height.pixel];
    }

    Pixel[2] pixelSize(Pixel[2]) { assert(false); }
}
