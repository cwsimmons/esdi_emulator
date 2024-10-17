# 
# Usage: To re-create this platform project launch xsct with below options.
# xsct C:\Users\chris.simmons\repos\esdi_emulator\firmware\esdi_emulator_platform\platform.tcl
# 
# OR launch xsct and run below command.
# source C:\Users\chris.simmons\repos\esdi_emulator\firmware\esdi_emulator_platform\platform.tcl
# 
# To create the platform in a different location, modify the -out option of "platform create" command.
# -out option specifies the output directory of the platform project.

platform create -name {esdi_emulator}\
-hw {../fpga/esdi_emulator/top.xsa}\
-proc {psu_cortexa53_0} -os {standalone} -arch {64-bit} -fsbl-target {psu_cortexa53_0} -out {.}

platform write
platform generate -domains 
platform active {esdi_emulator}
domain active {zynqmp_fsbl}
bsp reload
domain active {standalone_domain}
bsp reload
platform generate
bsp setlib -name xilffs -ver 5.0
bsp write
bsp reload
catch {bsp regenerate}
platform generate -domains standalone_domain 
bsp reload
