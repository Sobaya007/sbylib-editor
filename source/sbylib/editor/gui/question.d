module sbylib.editor.gui.question;

public import sbylib.editor.gui.item : Item;

import sbylib.graphics;
import std.typecons : Nullable;
import sbylib.editor.gui.container : Container;
import sbylib.editor.gui.selection : Selection;

class Question : Item, IAction {

    mixin ImplPos;
    mixin ImplParentalWorldMatrix!(parent);
    mixin ImplAction;

    private Container parent;
    private Selection[] selectionList;
    private EventContext context;
    private Nullable!size_t selectionIndex;

    this(Container parent, Selection[] selections) {
        this.parent = parent;
        this.context = new EventContext;
        this.selectionList = selections;
        foreach (s; selections) {
            s.parent = this;
        }
        this.setAlignment();
    }

    private void setAlignment() {
        import std.algorithm : map, sum;

        enum Margin = 100.pixel;

        const totalWidth = cast(int)(selectionList.length-1) * Margin;

        Pixel x = -totalWidth/2;
        foreach (selection; selectionList) {
            selection.pixelX = x;
            x += Margin;
        }
    }

    override void appear(ActionSequence builder) {
        foreach (selection; selectionList)
            selection.appear(builder);

        restart(builder);
    }

    override void restart(ActionSequence builder) {
        with (builder) {
            action(this);
            run({ this.context.unbind(); });
            run({ selectionList[selectionIndex].f(); });
        }
    }

    override void start() {
        with (context()) {
            when(KeyButton.Left.pressed).run({
                if (selectionIndex.isNull) {
                    selectionIndex = 0;
                    selectionList[selectionIndex].focus = true;
                    return;
                }
                if (selectionIndex == 0) return;
                selectionList[selectionIndex].focus = false;
                selectionIndex--;
                selectionList[selectionIndex].focus = true;
            });
            when(KeyButton.Right.pressed).run({
                if (selectionIndex.isNull) {
                    selectionIndex = selectionList.length-1;
                    selectionList[selectionIndex].focus = true;
                    return;
                }
                if (selectionIndex+1 == selectionList.length) return;
                selectionList[selectionIndex].focus = false;
                selectionIndex++;
                selectionList[selectionIndex].focus = true;
            });
            when(KeyButton.Enter.pressed).run({
                if (selectionIndex.isNull) return;
                auto action = selectionList[selectionIndex].select();
                when(action.finish).run({ this.notifyFinish(); });
            });
        }
        context.bind();
    }

    override void render2D() {
        foreach (selection; selectionList)
            selection.render2D();
    }

    override Pixel[2] pixelSize() {
        import std.algorithm : map, sum, maxElement;
        return [
            selectionList.map!(selection => selection.pixelWidth).sum,
            selectionList.map!(selection => selection.pixelHeight).maxElement,
        ];
    }

    override Pixel[2] pixelSize(Pixel[2] size) {
        assert(false);
    }

    mixin ImplPixelWidth;
    mixin ImplPixelHeight;
}
