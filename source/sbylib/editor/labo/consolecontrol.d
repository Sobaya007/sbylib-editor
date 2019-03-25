module sbylib.editor.labo.consolecontrol;

public import sbylib.editor.labo.console : Console;

import sbylib.graphics;

class ConsoleControl {
    EventContext context;
    alias context this;

    this(Canvas canvas, Console console) {
        this.context = new EventContext;

        with (context()) {
            when(Frame).then({
                with (canvas.getContext()) {
                    console.render();
                }
            });
            when(Char.typed).then((uint codepoint) {
                import std.conv : to;

                auto c = codepoint.to!char;
                console.write([c]);
            });
            when(KeyButton.Enter.pressed).then({
                console.interpret();
            });
            when(KeyButton.Tab.pressed).then({
                console.complete();
            });
            when(KeyButton.BackSpace.pressed.or(KeyButton.BackSpace.repeated)).then({
                console.backSpace();
            });
            when(KeyButton.Left.pressed.or(KeyButton.Left.repeated)).then({
                console.shift(-1);
            });
            when(KeyButton.Right.pressed.or(KeyButton.Right.repeated)).then({
                console.shift(+1);
            });
            when(KeyButton.Up.pressed).then({
                console.shiftHistory(-1);
            });
            when(KeyButton.Down.pressed).then({
                console.shiftHistory(+1);
            });
        }
    }

}
