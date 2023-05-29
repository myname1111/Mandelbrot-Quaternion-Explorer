use winit::event::{ElementState, KeyboardInput, VirtualKeyCode, WindowEvent};

#[repr(C)]
#[derive(Copy, Clone, Debug, bytemuck::Pod, bytemuck::Zeroable, Default)]
pub struct Camera {
    pos: [f32; 3],
    _padding: u32,
    rot: [[f32; 4]; 4],
}

#[derive(Default)]
pub struct CameraController {
    speed: f32,
    rotation_speed: f32,
    speed_multiplier: f32,
    smi: f32, // speed multiplier inverse
    is_forward_pressed: bool,
    is_backward_pressed: bool,
    is_left_pressed: bool,
    is_right_pressed: bool,
    is_up_pressed: bool,
    is_down_pressed: bool,
    is_yaw_left: bool,
    is_yaw_right: bool,
    is_pitch_up: bool,
    is_pitch_down: bool,
    is_scale_up: bool,
    is_scale_down: bool,
    yaw: f32,
    pitch: f32,
}

fn pos_updated(
    camera: &mut Camera,
    is_backward: bool,
    index: usize,
    rotated: &[[f32; 3]],
    speed: f32,
) {
    let speed = if is_backward { speed * -1.0 } else { speed };
    camera.pos[0] += speed * rotated[index][0];
    camera.pos[1] += speed * rotated[index][1];
    camera.pos[2] += speed * rotated[index][2];
}

impl CameraController {
    pub fn new(speed: f32, rotation_speed: f32, speed_multiplier: f32) -> Self {
        Self {
            rotation_speed,
            speed,
            speed_multiplier,
            smi: 1.0 / speed_multiplier,
            ..Default::default()
        }
    }

    pub fn process_events(&mut self, event: &WindowEvent) -> bool {
        match event {
            WindowEvent::KeyboardInput {
                input:
                    KeyboardInput {
                        state,
                        virtual_keycode: Some(keycode),
                        ..
                    },
                ..
            } => {
                let is_pressed = *state == ElementState::Pressed;
                match keycode {
                    VirtualKeyCode::W | VirtualKeyCode::Up => {
                        self.is_forward_pressed = is_pressed;
                        true
                    }
                    VirtualKeyCode::A | VirtualKeyCode::Left => {
                        self.is_left_pressed = is_pressed;
                        true
                    }
                    VirtualKeyCode::S | VirtualKeyCode::Down => {
                        self.is_backward_pressed = is_pressed;
                        true
                    }
                    VirtualKeyCode::D | VirtualKeyCode::Right => {
                        self.is_right_pressed = is_pressed;
                        true
                    }
                    VirtualKeyCode::E | VirtualKeyCode::Space => {
                        self.is_up_pressed = is_pressed;
                        true
                    }
                    VirtualKeyCode::Q | VirtualKeyCode::RShift | VirtualKeyCode::LShift => {
                        self.is_down_pressed = is_pressed;
                        true
                    }
                    VirtualKeyCode::J => {
                        self.is_pitch_down = is_pressed;
                        true
                    }
                    VirtualKeyCode::U => {
                        self.is_pitch_up = is_pressed;
                        true
                    }
                    VirtualKeyCode::H => {
                        self.is_yaw_left = is_pressed;
                        true
                    }
                    VirtualKeyCode::K => {
                        self.is_yaw_right = is_pressed;
                        true
                    }
                    VirtualKeyCode::Key0 => {
                        self.is_scale_up = is_pressed;
                        true
                    }
                    VirtualKeyCode::Key1 => {
                        self.is_scale_down = is_pressed;
                        true
                    }
                    _ => false,
                }
            }
            _ => false,
        }
    }

    pub fn update_camera(&mut self, camera: &mut Camera) {
        println!("{}", self.speed);

        let (pitch_sin, pitch_cos) = self.pitch.sin_cos();
        let (yaw_sin, yaw_cos) = self.yaw.sin_cos();

        camera.rot = [
            [yaw_cos, 0.0, yaw_sin, 0.0],
            [pitch_sin * yaw_sin, pitch_cos, -pitch_sin * yaw_cos, 0.0],
            [pitch_cos * -yaw_sin, pitch_sin, pitch_cos * yaw_cos, 0.0],
            [0.0, 0.0, 0.0, 1.0],
        ];

        let rotated = [
            [yaw_cos, 0.0, yaw_sin],
            [camera.rot[1][0], pitch_cos, camera.rot[1][2]],
            [camera.rot[2][0], pitch_sin, camera.rot[2][2]],
        ];

        if self.is_left_pressed {
            pos_updated(camera, true, 0, &rotated, self.speed)
        }

        if self.is_right_pressed {
            pos_updated(camera, false, 0, &rotated, self.speed)
        }

        if self.is_backward_pressed {
            pos_updated(camera, true, 2, &rotated, self.speed)
        }

        if self.is_forward_pressed {
            pos_updated(camera, false, 2, &rotated, self.speed)
        }

        if self.is_down_pressed {
            pos_updated(camera, true, 1, &rotated, self.speed)
        }

        if self.is_up_pressed {
            pos_updated(camera, false, 1, &rotated, self.speed)
        }

        if self.is_pitch_down {
            self.pitch -= self.rotation_speed
        }

        if self.is_pitch_up {
            self.pitch += self.rotation_speed
        }

        if self.is_yaw_right {
            self.yaw -= self.rotation_speed
        }

        if self.is_yaw_left {
            self.yaw += self.rotation_speed
        }

        if self.is_scale_up {
            self.speed *= self.speed_multiplier
        }

        if self.is_scale_down {
            self.speed *= self.smi
        }
    }
}
