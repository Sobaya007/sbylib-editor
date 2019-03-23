module sbylib.editor.labo.consolecontrol;

public import sbylib.editor.labo.console : Console;

import sbylib.graphics;

class ConsoleControl {
    EventContext context;
    alias context this;

    this(Canvas canvas, Console console) {
        this.context = new EventContext;

        with (context()) {
            when(Frame).run({
                with (canvas.getContext()) {
                    console.render();
                }
            });
            when(Char.typed).run((uint codepoint) {
                import std.conv : to;

                auto c = codepoint.to!char;
                console.write([c]);
            });
            when(KeyButton.Enter.pressed).run({
                console.interpret();
            });
            when(KeyButton.Tab.pressed).run({
                console.complete();
            });
            when(KeyButton.BackSpace.pressed.or(KeyButton.BackSpace.repeated)).run({
                console.backSpace();
            });
            when(KeyButton.Left.pressed.or(KeyButton.Left.repeated)).run({
                console.shift(-1);
            });
            when(KeyButton.Right.pressed.or(KeyButton.Right.repeated)).run({
                console.shift(+1);
            });
            when(KeyButton.Up.pressed).run({
                console.shiftHistory(-1);
            });
            when(KeyButton.Down.pressed).run({
                console.shiftHistory(+1);
            });
        }
    }

}
