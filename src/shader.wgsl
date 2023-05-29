struct VertexInput {
    @location(0) position: vec3<f32>,
    @location(1) real_pos: vec3<f32>,
};

struct VertexOutput {
    @builtin(position) clip_position: vec4<f32>,
    @location(0) real_pos: vec3<f32>,
};

struct ZoomUniform {
    zoom: f32,
};

@group(0) @binding(0)
var<uniform> zoom: ZoomUniform;

struct CameraUniform {
    pos: vec3<f32>,
    rot: mat4x4<f32>
}

@group(0) @binding(1)
var<uniform> cam: CameraUniform;

const MAX_ITERATIONS = 50;
/* const FOCUS = vec2<f32>(-0.5577, -0.6099); */

const MAX_STEPS = 200;
const FOV = 90;
const SIZE = 10.0;
const OBJ_POS = vec3<f32>(0.0, 0.0, 0.0);
const LIGHT_POS = vec3<f32>(-50.0, 50.0, 50.0);
const MIN_DISTANCE = 0.00001;
const MAX_DISTANCE = 100.0;
const DELTA = 0.001;
const AMBIENT_LIGHT = vec3<f32>(0.1, 0.1, 0.1);
const LIGHT_INTENSITY = 0.4;

@vertex
fn vs_main(
    model: VertexInput,
) -> VertexOutput {
    var out: VertexOutput;
    out.clip_position = vec4<f32>(model.position, 1.0);
    out.real_pos = (cam.rot * vec4<f32>(model.real_pos, 1.0)).xyz;
    return out;
}

// Complex multiplication
// (a + bi)(c + di) = ac - bd + (ad + bc)i

// Fragment shader

fn quaternion_mul(a: vec4<f32>, b: vec4<f32>) -> vec4<f32> {
    // (a + bi + cj + dk)(e + fi + gk + hi) = 
    // 1(ae - bf - cg - dh) + 
    // i(be + af + ch - dg) + 
    // j(ag - bh + ce + df) + 
    // k(ah + bg - cf + de)
    // CHECK AGAIN!!!
    return vec4<f32>(
        a.x * b.x - a.y * b.y - a.z * b.z - a.w * b.w,
        a.y * b.x + a.x * b.y + a.z * b.w - a.w * b.z,
        a.x * b.z - a.y * b.w + a.z * b.x + a.w * b.y,
        a.x * b.w + a.y * b.z - a.z * b.y + a.w * b.x
    );
}

fn mandelbrot(pos: vec4<f32>) -> f32 {
    var iters = 0;
    let c = pos;
    var z = vec4(pos.x, -pos.z, -pos.y, pos.w);
    var dz = vec4(1.0, vec3(0.0));

    while iters <= MAX_ITERATIONS {
        dz = 2.0 * vec4(z.x * dz.x - dot(z.yzw, dz.yzw), z.x * dz.yzw + dz.x * z.yzw + cross(z.yzw, dz.yzw));
        z = quaternion_mul(z, z) + c;

        let z2 = dot(z, z);
        if z2 > 4.0 {
            break
        }

        iters++;
    }

    let r = length(z);
    return 0.5 * log(r) * r / length(dz);
}

fn DE(pos: vec3<f32>) -> f32 {
    return mandelbrot(to_quat(pos));
}

fn normals(pos: vec3<f32>) -> vec3<f32> {
    return normalize(vec3(
        DE(vec3(pos.x + DELTA, pos.y, pos.z)) - DE(vec3(pos.x - DELTA, pos.y, pos.z)),
        DE(vec3(pos.x, pos.y + DELTA, pos.z)) - DE(vec3(pos.x, pos.y - DELTA, pos.z)),
        DE(vec3(pos.x, pos.y, pos.z + DELTA)) - DE(vec3(pos.x, pos.y, pos.z - DELTA)),
    ));
}

/**
 * Lighting via Phong illumination.
 * 
 * The vec3 returned is the RGB color of that point after lighting is applied.
 * k_a: Ambient color
 * k_d: Diffuse color
 * k_s: Specular color
 * alpha: Shininess coefficient
 * p: position of point being lit
 * eye: the position of the camera
 *
 * See https://en.wikipedia.org/wiki/Phong_reflection_model#Description
 */
const K_A = vec3<f32>(0.2, 0.2, 0.2);
const K_D = vec3<f32>(0.7, 0.2, 0.2);
const K_S = vec3<f32>(1.0, 1.0, 1.0);
const SHININESS = 10.0;

fn phong(p: vec3<f32>) -> vec3<f32> {
    var color = AMBIENT_LIGHT * K_A;

    let N = normals(p);
    let L = normalize(LIGHT_POS - p);
    let V = normalize(cam.pos - p);
    let R = normalize(reflect(-L, N));

    let dot_LN = saturate(dot(L, N));
    let dot_RV = dot(R, V);

    if dot_LN >= 0.0 && dot_RV < 0.0 {
        color += LIGHT_INTENSITY * K_D * dot_LN;
    } else if dot_LN >= 0.0 {
        color += LIGHT_INTENSITY * (K_D * dot_LN + K_S * pow(dot_RV, SHININESS));
    }

    return color;
}

// Input a pos, outputs a color
fn on_hit(pos: vec3<f32>) -> vec3<f32> {
    // return normals(pos);
    return phong(pos);
}

fn to_quat(pos: vec3<f32>) -> vec4<f32> {
    return vec4(pos, 0.0);
}

fn get_color(real_pos: vec3<f32>) -> vec3<f32> {
    let real_pos = vec3(real_pos.xy, real_pos.z);
    let ray_direction = normalize(real_pos);
    var ray_pos = real_pos + cam.pos;

    var distance = DE(ray_pos);
    var steps = 0;

    while steps <= MAX_STEPS && distance > MIN_DISTANCE && distance < MAX_DISTANCE {
        ray_pos += ray_direction * distance;
        distance = DE(ray_pos);
        steps++;
    }

    if distance < MIN_DISTANCE {
        return on_hit(ray_pos);
    } else {
        return vec3(0.0, 0.0, 0.0);
    }
}

@fragment
fn fs_main(in: VertexOutput) -> @location(0) vec4<f32> {
    let pos = mat4x3(
        in.real_pos + vec3(0.0001, 0.0, 0.0),
        in.real_pos + vec3(0.0, 0.0001, 0.0),
        in.real_pos - vec3(0.0001, 0.0, 0.0),
        in.real_pos - vec3(0.0, 0.0001, 0.0),
    );
    let color = (
        get_color(in.real_pos) + 
        get_color(pos.x) + 
        get_color(pos.y) + 
        get_color(pos.z) + 
        get_color(pos.w)
    ) / 5.0;
    return vec4<f32>(color, 1.0);
    /* return vec4<f32>(vec3(f32(steps / MAX_STEPS)), 1.0); */
}
