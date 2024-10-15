## Project Generation

1. Open Vivado, in the TCL console, change to the `fpga` directory of this repo, and run `source esdi_emulator.tcl`
2. Generate bitstream
3. Export hardware (no need to include bitstream) as `fpga/esdi_emulator/top.xsa`
4. Open the Software Command Line Tool (`xsct%` prompt)
5. Change to `firmware` directory, and run `source platform.tcl`
6. Open (Classic) Vitis IDE with workspace set to `firmware`
7. Choose `File > Import...`, choose to import from a git repository, choose to import from existing local repo,
choose the repo name from the list, choose `Import existing Eclipse projects`, select the `firmware` directory from the tree,
ensure that `esdi_emulator`, `esdi_emulator_system`, and `esdi_emulator_platform`, Finish.
