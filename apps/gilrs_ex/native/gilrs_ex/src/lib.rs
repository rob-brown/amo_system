use gilrs::{Axis, Button, Event, EventType, Gilrs};
use rustler::{Env, NifStruct, ResourceArc, Term};
use std::sync::Mutex;

mod atoms {
    rustler::atoms! {
        ok,
        error,
        none,
        button_pressed,
        button_released,
        axis_changed,
        connected,
        disconnected,
    }
}

struct GilrsResource {
    gilrs: Mutex<Gilrs>,
}

#[derive(NifStruct)]
#[module = "GilrsEx.Event"]
struct GilrsEvent {
    gamepad_id: usize,
    event_type: String,
    button: Option<String>,
    button_code: Option<u32>,
    axis: Option<String>,
    axis_code: Option<u32>,
    value: Option<f32>,
}

fn load(env: Env, _: Term) -> bool {
    rustler::resource!(GilrsResource, env);
    true
}

#[rustler::nif]
fn new() -> Result<ResourceArc<GilrsResource>, String> {

    match Gilrs::new() {
        Ok(gilrs) => Ok(ResourceArc::new(GilrsResource {
            gilrs: Mutex::new(gilrs),
        })),
        Err(e) => Err(format!("Failed to create Gilrs: {:?}", e)),
    }
}

#[rustler::nif]
fn next_event(resource: ResourceArc<GilrsResource>) -> Result<GilrsEvent, rustler::Atom> {
    let mut gilrs = resource
        .gilrs
        .lock()
        .map_err(|_| atoms::error())?;

    match gilrs.next_event() {
        Some(Event { id, event, .. }) => {
            let gamepad_id = usize::from(id);
            let (event_type, button, button_code, axis, axis_code, value) = match event {
                EventType::ButtonPressed(btn, code) => (
                    "button_pressed".to_string(),
                    Some(button_to_string(btn)),
                    Some(code.into_u32()),
                    None,
                    None,
                    None,
                ),
                EventType::ButtonReleased(btn, code) => (
                    "button_released".to_string(),
                    Some(button_to_string(btn)),
                    Some(code.into_u32()),
                    None,
                    None,
                    None,
                ),
                EventType::AxisChanged(ax, val, code) => (
                    "axis_changed".to_string(),
                    None,
                    None,
                    Some(axis_to_string(ax)),
                    Some(code.into_u32()),
                    Some(val),
                ),
                EventType::Connected => ("connected".to_string(), None, None, None, None, None),
                EventType::Disconnected => ("disconnected".to_string(), None, None, None, None, None),
                _ => return Err(atoms::none()),
            };

            Ok(GilrsEvent {
                gamepad_id,
                event_type,
                button,
                button_code,
                axis,
                axis_code,
                value,
            })
        }
        None => Err(atoms::none()),
    }
}

#[rustler::nif]
fn connected_gamepads(resource: ResourceArc<GilrsResource>) -> Result<Vec<usize>, rustler::Atom> {
    let gilrs = resource
        .gilrs
        .lock()
        .map_err(|_| atoms::error())?;

    let gamepads: Vec<usize> = gilrs
        .gamepads()
        .map(|(id, _)| usize::from(id))
        .collect();

    Ok(gamepads)
}

#[rustler::nif]
fn gamepad_name(
    resource: ResourceArc<GilrsResource>,
    id: usize,
) -> Result<String, rustler::Atom> {
    let gilrs = resource
        .gilrs
        .lock()
        .map_err(|_| atoms::error())?;

    gilrs
        .gamepads()
        .find(|(gp_id, _)| usize::from(*gp_id) == id)
        .map(|(_, gamepad)| gamepad.name().to_string())
        .ok_or(atoms::error())
}

fn button_to_string(button: Button) -> String {
    match button {
        Button::South => "south".to_string(),
        Button::East => "east".to_string(),
        Button::North => "north".to_string(),
        Button::West => "west".to_string(),
        Button::C => "c".to_string(),
        Button::Z => "z".to_string(),
        Button::LeftTrigger => "left_trigger".to_string(),
        Button::LeftTrigger2 => "left_trigger2".to_string(),
        Button::RightTrigger => "right_trigger".to_string(),
        Button::RightTrigger2 => "right_trigger2".to_string(),
        Button::Select => "select".to_string(),
        Button::Start => "start".to_string(),
        Button::Mode => "mode".to_string(),
        Button::LeftThumb => "left_thumb".to_string(),
        Button::RightThumb => "right_thumb".to_string(),
        Button::DPadUp => "dpad_up".to_string(),
        Button::DPadDown => "dpad_down".to_string(),
        Button::DPadLeft => "dpad_left".to_string(),
        Button::DPadRight => "dpad_right".to_string(),
        Button::Unknown => "unknown".to_string(),
    }
}

fn axis_to_string(axis: Axis) -> String {
    match axis {
        Axis::LeftStickX => "left_stick_x".to_string(),
        Axis::LeftStickY => "left_stick_y".to_string(),
        Axis::LeftZ => "left_z".to_string(),
        Axis::RightStickX => "right_stick_x".to_string(),
        Axis::RightStickY => "right_stick_y".to_string(),
        Axis::RightZ => "right_z".to_string(),
        Axis::DPadX => "dpad_x".to_string(),
        Axis::DPadY => "dpad_y".to_string(),
        Axis::Unknown => "unknown".to_string(),
    }
}

rustler::init!("Elixir.GilrsEx.Native", load = load);
