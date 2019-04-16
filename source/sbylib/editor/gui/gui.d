module sbylib.editor.gui.gui;

import sbylib.graphics : ActionSequence, EventContext, Pixel, pixel, Color;
import sbylib.editor.gui.item : Item;
import sbylib.editor.gui.blank : Blank;
import sbylib.editor.gui.selection : Selection;
import sbylib.editor.gui.container : Container;
import std.traits : isSomeString;

class GUI {

    private static GUI[string] cache;

    static GUI opCall(string name = "") {
        if (auto r = name in cache)
            return *r;
        return cache[name] = new GUI(name);
    }

    ActionSequence actionSequence;
    alias actionSequence this;

    private string name;
    private EventContext context;
    private Container rootContainer;
    private Blank[string] blankList;
    private Item[] itemList;
    private int actionCount;

    Pixel lineHeight = 30.pixel;
    string fontPath;

    private this(string name) {
        import sbylib.graphics : Canvas, CanvasBuilder, getContext, when, Frame, then, KeyButton, pressed;
        import sbylib.wrapper.glfw : Window;
        import sbylib.editor.util : fontPath;

        this.name = name;
        this.fontPath = fontPath("consola.ttf");
        this.context = new EventContext;
        this.rootContainer = new Container(this);
        this.actionSequence = ActionSequence();

        Canvas windowCanvas;
        with (CanvasBuilder()) {
            color.enable = true;
            depth.enable = true;
            windowCanvas = build(Window.getCurrentWindow());
        }
   
        with (context()) {
            when(Frame).then({
                with (windowCanvas.getContext()) {
                    this.rootContainer.render2D();
                }
            });
        }
        context.bind();
        when(actionSequence.finish).then({
            context.unbind();
        });
    }

    ~this() {
        cache.remove(this.name);
    }

    void background(Color color) {
        import sbylib.editor.gui.background : Background;

        append(new Background(this, rootContainer, color));
    }

    void text(String)(String txt) 
        if (isSomeString!(String))
    {
        import sbylib.editor.gui.textbox : TextBox;

        append(new TextBox(this, rootContainer, txt));
    }

    void inputForm(Args...)(Args args) {
        import sbylib.editor.gui.inputform : InputForm;

        append(new InputForm(this, rootContainer, args));
    }

    void question(Selection[] selections...) {
        import sbylib.editor.gui.question : Question;

        append(new Question(rootContainer, selections));
    }

    Blank blank(string name) 
        in (name !in blankList)
    {
        auto blank = new Blank(this, name);
        blankList[name] = blank;
        return blank;
    }

    Selection selection(string value) {
        return new Selection(this, value);
    }

    Selection selection(string value, void delegate() f) {
        return new Selection(this, value, f);
    }

    void back(int num) {
        import sbylib.editor.gui.textbox : TextBox;
        with (actionSequence) {
            action(this.rootContainer.popBack(num));
            itemList[$-1-num].restart(actionSequence);
            foreach (i; 0..num) 
                action(this.rootContainer.append(itemList[$-num+i]));
        }
    }

    void append(Item item) {
        with (actionSequence) {
            run({ itemList ~= item; });
            action(this.rootContainer.append(item));
        }
    }

    void waitKey() {
        import sbylib.graphics : Key, KeyButton, pressed, when, gthen = then;
        with (actionSequence) {
            run((resolve) {
                when(Key.pressed).gthen((KeyButton b) { resolve(); });
            });
        }
    }

    void start() {
        this.actionSequence.start();
    }

    string get(string name) {
        return blankList[name].value;
    }
}
