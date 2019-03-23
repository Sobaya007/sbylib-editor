import sbylib.editor;
import sbylib.graphics;

void func(Project project, EventContext context) {
    auto console = project.get!Console("console");
    auto camera = project.get!Camera("camera");
    auto canvas = project.get!Canvas("canvas");
    auto window = project.get!Window("window");
    with (context()) {
        with (TestEntity.Builder()) {
            geometry = GeometryLibrary().buildBox();

            auto e = build();
            e.blend = true;
            auto e2 = build();
            e2.blend = true;

            when(Frame).run({ 
                with (canvas.getContext()) {
                    camera.capture(e);
                    camera.capture(e2);
                }
                e.rot *= mat3.axisAngle(vec3(1,0,0), 1.deg);
            });

            e2.pos += vec3(0,3,0);
            e2.scale *= 0.5;
        }
    }
}

class TestMaterial : Material {
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

        void main() {
            fragColor = vec4(uv2, 0, 0.5);
        }
    };
}

class TestEntity : Entity {
    mixin ImplPos;
    mixin ImplRot;
    mixin ImplScale;
    mixin ImplWorldMatrix;
    mixin Material!(TestMaterial);
    mixin ImplUniform;
    mixin ImplBuilder;
}

mixin(Register!(func));
