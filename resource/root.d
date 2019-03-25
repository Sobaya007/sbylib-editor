import sbylib.graphics;
import sbylib.editor;
import sbylib.wrapper.glfw;

mixin(Register!(root));

void root(Project proj, EventContext context) {

    setupWindow(proj);
    setupCanvas(proj);
    setupCamera(proj);
    setupFloor(proj);
    setupConsole(proj);

    auto cameraControl = proj.get!CameraControl("cameraControl");
    auto consoleControl = proj.get!ConsoleControl("consoleControl");

    cameraControl.bind();
    with (cameraControl()) {
        when((Ctrl + KeyButton.KeyP).pressed).then({
            cameraControl.unbind();
            consoleControl.bind();
        });
    }

    with (consoleControl()) {
        when(KeyButton.Escape.pressed).then({
            cameraControl.bind();
            consoleControl.unbind();
        });
    }

    proj.loadErrorHandler = (Exception e) {
        with (GUI()) {
            lineHeight = 18.pixel;
            background(Color(0,0,0,0.5));
            text(e.msg);
            waitKey();
            start();
        }
    };

    proj.load();
}

private void setupWindow(Project proj) {
    auto window = Window.getCurrentWindow();
    auto videoMode = Screen.getPrimaryScreen().currentVideoMode;
    window.pos = [0.pixel, 0.pixel];
    window.size = [videoMode.width.pixel/2, videoMode.height.pixel-200.pixel];

    proj["window"] = window;
}

private void setupCanvas(Project proj) {
    auto window = Window.getCurrentWindow();
    auto videoMode = Screen.getPrimaryScreen().currentVideoMode;
    with (CanvasBuilder()) {
        color.enable = true;
        depth.enable = true;
        size = [videoMode.width.pixel/2, videoMode.height.pixel-200.pixel];
        proj["canvas"] = build(window);
    }
}

private void setupCamera(Project proj) {
    with (PerspectiveCamera.Builder()) {
        near = 0.1;
        far = 10;
        fov = 90.deg;
        aspect = 1;

        auto camera = build();
        camera.pos = vec3(0);
        proj["camera"] = cast(Camera)camera;

        proj["cameraControl"] = new CameraControl(camera);
    }
}

private void setupFloor(Project proj) {
    Floor f;
    with (Floor.Builder()) {
        geometry = GeometryLibrary().buildPlane().transform(
                mat3.axisAngle(vec3(1,0,0), 90.deg) * mat3.scale(vec3(10)));
        f = build();
        f.pos = vec3(0,-2,0);
    }
    proj["floor"] = f;

    auto canvas = proj.get!Canvas("canvas");
    auto camera = proj.get!Camera("camera");
    when(Frame).then({
        with (canvas.getContext()) {
            clear(ClearMode.Color, ClearMode.Depth);
            camera.capture(f);
        }
    });
}

void setupConsole(Project proj) {
    auto console = new Console(proj);
    proj["console"] = console;

    auto canvas = proj.get!Canvas("canvas");
    auto consoleControl = new ConsoleControl(canvas, console);
    proj["consoleControl"] = consoleControl;
}

class FloorMaterial : Material {
    mixin VertexShaderSource!q{
        #version 450

        in vec4 position;
        in vec2 uv;
        out vec2 uv2;
        uniform mat4 worldMatrix;
        uniform mat4 viewMatrix;
        uniform mat4 projectionMatrix;

        void main() {
            gl_Position = projectionMatrix * viewMatrix * worldMatrix * position;
            uv2 = uv;
        }
    };

    mixin FragmentShaderSource!q{
        #version 450

        in vec2 uv2;
        out vec4 fragColor;

        float value1() {
            const float size = 0.1 / 8;
            vec2 po = mod(uv2 / (size * 2), vec2(1)) - 0.5;
            if (po.x * po.y > 0) {
                return 0.2;
            } else {
                return 0.3;
            }
        }

        float value2() {
            const float size = 0.1 / 8;
            vec2 po = mod(uv2 / (size * 2), vec2(1)) - 0.5;
            if (po.x * po.y > 0) {
                return 0.2;
            } else {
                return 0.1;
            }
        }

        float value() {
            const float size = 0.1;
            vec2 po = mod(uv2 / (size * 2), vec2(1)) - 0.5;
            if (po.x * po.y > 0) {
                return value1();
            } else {
                return value2();
            }
        }

        void main() {
            fragColor = vec4(vec3(value()), 1);
        }
    };
}

class Floor : Entity {
    mixin ImplPos;
    mixin ImplRot;
    mixin ImplScale;
    mixin ImplWorldMatrix;
    mixin Material!(FloorMaterial);
    mixin ImplUniform;
    mixin ImplBuilder;
}
