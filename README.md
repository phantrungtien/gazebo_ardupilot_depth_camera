# Iris + Intel RealSense D435i

Gazebo Harmonic simulation of an ArduPilot Iris quadrotor carrying a **RealSense
D435i depth camera**, nose-mounted and forward-facing, replacing the 3-axis
gimbal it used to fly with.

Every dimension, offset, mass and FOV in the camera model comes from Intel's own
URDF (`realsense2_description`) and the D400-series datasheet — not from rounded
catalogue figures.

## Layout, and why ArduPilot's repo is not in here

```
gz_ws/
  src/drone_vision/          <- this repository. Only our work.
      models/realsense_d435i/    the D435i
      models/iris_with_d435i/    iris + D435i (includes iris_with_standoffs)
      models/gate_ring/          racing gate
      worlds/gates_course.sdf    the course
  src/ardupilot_gazebo/      <- cloned separately, NEVER modified, gitignored
```

`ardupilot_gazebo` is left as a pristine clone so `git pull` on it can never
conflict with our changes. Nothing here edits it. Our models reach into it purely
through `model://` URIs, which Gazebo resolves across `GZ_SIM_RESOURCE_PATH` —
it does not care which repository a model came from.

## Setup

```bash
git clone https://github.com/ArduPilot/ardupilot_gazebo src/ardupilot_gazebo
cd src/ardupilot_gazebo && mkdir -p build && cd build
cmake .. -DCMAKE_BUILD_TYPE=RelWithDebInfo && make -j4
cd ../../..

source setup.bash
gz sim -v3 -r src/drone_vision/worlds/gates_course.sdf
```

The world opens with three `ImageDisplay` panels (color, depth, infra1) already
docked. Cameras in Gazebo only render while something is subscribed — an open
panel *is* that subscriber, so closing them costs nothing.

To fly it, ArduPilot SITL in a second terminal:

```bash
sim_vehicle.py -v ArduCopter -f gazebo-iris --model JSON --map --console
```

To stop it: `Ctrl-C` in the terminal running it. If it was backgrounded:

```bash
pkill -f "gz sim"
```

`gz` is a Ruby launcher, so all three processes (`gz sim`, `gz sim server`,
`gz sim gui`) report a process *name* of `ruby` — `pkill gz` and `pkill -x gz`
match nothing. `-f` is the only thing that works, and it matches against whole
command lines, so it also kills any script or shell whose own command line
contains the string `gz sim`. Harmless from an interactive prompt; it will take
a launcher script down with it.

## The camera

| Stream | Resolution | FOV | Topic |
|---|---|---|---|
| depth | 848×480 | 87° × 56.5° | `/d435i/depth/image_rect_raw` |
| color | 848×480 | 69° × 42.5° | `/d435i/color/image_raw` |
| infra1 / infra2 | 848×480 | 87° | `/d435i/infra{1,2}/image_rect_raw` |
| imu (BMI055) | 200 Hz | — | `/d435i/imu` |

848×480 is not a style choice. Gazebo derives vertical FOV from
`horizontal_fov` and the aspect ratio, so at 640×480 an 87° hfov yields a 70.9°
vfov against the datasheet's 58° — 13° wrong, and every back-projection down the
image Y axis inherits it. At 848×480 it comes out 56.5°, inside spec. Verified
against the published `camera_info`: `fx = 446.80` (depth), `616.92` (color).

Topics and frames are named after `realsense-ros`, so code written here should
run against the real driver unchanged.

**Depth and color do not share an optical centre** — they are 15 mm apart, as on
the hardware, and each stream reports its own frame. Fusing them without a
transform is therefore a visible mistake here, instead of a free lunch that
disappears the day you plug in a real D435i.

## Things the simulator does NOT give you

Measured, not assumed. Handle these in code:

- **Depth noise does not grow with range.** Gazebo only offers a constant stddev.
  It is set to 0.014 m, which is the real quadratic error evaluated at Z = 2 m.
  Beyond that the sim is optimistically clean. Real: `σ_Z = Z²·σ_d/(f·B)`.
- **The min-Z blind zone is not enforced.** A real D435i sees nothing closer than
  ~0.195 m; the sim happily returns depth at 0.17 m. Reject `Z < 0.195` yourself.
- **`/points` is in a different frame convention than the depth image.** Gazebo's
  own point cloud is body-frame (X forward), while back-projecting the depth
  image through `K` lands in the optical frame (Z forward) — under the *same*
  `frame_id`. Do not bridge `/points` straight through; build the cloud from
  depth + `camera_info` (`depth_image_proc`) like the real stack does.
- **No IR emitter.** The sim's infra pair has no projected dot pattern. That
  matches a real D435i with the emitter *off*, which is how VIO is flown anyway.
- **RGB distortion is left empty.** Coefficients are per-unit calibration data,
  not a spec number. Read yours with `rs-enumerate-devices -c`.
- **Propellers do not break.** A prop strike is a real collision here (the rotors
  have collision discs and the gate has collision), the drone tumbles and
  ArduPilot's crash detection fires — but the prop keeps spinning and making full
  thrust. Outdoors it would shatter and the drone would drop.
