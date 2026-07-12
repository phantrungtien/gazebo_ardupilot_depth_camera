#!/usr/bin/env bash
# source this: `source setup.bash`
#
# The models live in two repos on purpose (see README). Gazebo does not care
# which repo a model:// URI resolves out of, as long as both are on the path:
#
#   gates_course.sdf  (drone_vision)
#     -> iris_with_d435i  (drone_vision)
#          -> iris_with_standoffs  (ardupilot_gazebo)
#          -> ArduPilotPlugin.so   (ardupilot_gazebo/build)
#     -> gate_ring, realsense_d435i  (drone_vision)

GZ_WS="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
AG="$GZ_WS/src/ardupilot_gazebo"
DV="$GZ_WS/src/drone_vision"

if [ ! -d "$AG/build" ]; then
  echo "ardupilot_gazebo is not built at $AG/build - see README" >&2
fi

export GZ_SIM_SYSTEM_PLUGIN_PATH="$AG/build${GZ_SIM_SYSTEM_PLUGIN_PATH:+:$GZ_SIM_SYSTEM_PLUGIN_PATH}"
export GZ_SIM_RESOURCE_PATH="$AG/models:$DV/models:$DV/worlds${GZ_SIM_RESOURCE_PATH:+:$GZ_SIM_RESOURCE_PATH}"

echo "gz_ws ready. Run:  gz sim -v3 -r $DV/worlds/gates_course.sdf"
