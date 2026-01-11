#!/bin/bash

sudo docker run -it --mount type=bind,source="$PWD/..",target=/home/adventoffpga --entrypoint=/bin/bash ubuntu-verilator-cocotb
