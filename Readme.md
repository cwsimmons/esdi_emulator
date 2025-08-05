# ESDI Disk Emulator

This is a work in progress emulator of Enhanced Small Disk Interface (ESDI) hard drives. The drive image is stored on an SD card. The current implementation is based on a Zynq Ultrascale FPGA, but ought to be easily adapted to Zynq 7000 (adapting cache coherency will be the trickiest part most likely).

## Technical Overview

I have attempted to keep most logic in the processor's firmware within reason. The FPGA fabric is responsible for the following:
* Deserializing commands received over the ESDI serial command interface and serializing responses.
* Keeping track of the rotation of the disk, generating index and sector pulses when appropriate.
* Serializing read data and sending it to the controller.
* Deserializing write data from the controller and muxing it with read data in accordance with the write gate signal.
* Using DMA to read and write sectors to DDR memory.

The processor is responsible for the following:
* Reading the drive configuration from the emulation image file and setting up the hardware's registers accordingly.
* Managing DMA descriptors.
    * For the read datapath this means determining the next sector to be read. This is done 15 microseconds before the next sector is set to begin so that the drive appears responsive to head changes.
    * For the write datapath this means waiting for a sector to be dirty and then providing a descriptor with the appropriate address.
* Keeping track of whether the drive is selected.
* Handling commands and responding to queries received on the serial command interface.
* Committing dirty sectors back to the SD card.
* Loading cylinders from the SD card into DDR memory when the controller seeks to a cylinder not already loaded. (This is not yet implemented)

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

## License

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program. If not, see <https://www.gnu.org/licenses/>.