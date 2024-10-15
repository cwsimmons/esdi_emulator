# 
# Usage: To re-create this platform project launch xsct with below options.
# xsct C:\Users\chris.simmons\repos\esdi_emulator\firmware\esdi_emulator_platform\platform.tcl
# 
# OR launch xsct and run below command.
# source C:\Users\chris.simmons\repos\esdi_emulator\firmware\esdi_emulator_platform\platform.tcl
# 
# To create the platform in a different location, modify the -out option of "platform create" command.
# -out option specifies the output directory of the platform project.

platform create -name {esdi_emulator_platform}\
-hw {../fpga/esdi_emulator/top.xsa}\
-proc {microblaze_0} -os {standalone} -out {.}

platform write
platform generate -domains 
platform active {esdi_emulator_platform}
platform generate
