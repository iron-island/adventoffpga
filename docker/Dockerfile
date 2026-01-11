FROM ubuntu:25.04

RUN apt-get update
# Just in case a text editor is needed
RUN apt-get install -y vim

#-----------
# Verilator
#-----------
# Git quick install, since package manager only has up to verilator=5.032-1,
#   and cocotb later on requires at least verilator=5.036
# Ref: https://verilator.org/guide/latest/install.html#git-install

# Dependencies, removed zlibc since it no longer exists and instructions state it can be ignored
RUN apt-get install -y git help2man perl python3 make autoconf g++ flex bison ccache
RUN apt-get install -y libgoogle-perftools-dev numactl perl-doc
RUN apt-get install -y libfl2
RUN apt-get install -y libfl-dev
RUN apt-get install -y zlib1g zlib1g-dev

# Build
RUN git clone https://github.com/verilator/verilator /home/verilator

RUN unset VERILATOR_ROOT
WORKDIR /home/verilator
RUN git pull
RUN git checkout v5.044

RUN autoconf
RUN ./configure
RUN make
RUN make install

#--------
# cocotb
#--------
# Ref: https://docs.cocotb.org/en/stable/install.html
# Added --break-system-packages to ignore pip install errors
RUN apt-get install -y python3 python3-pip
RUN pip install "cocotb~=2.0" --break-system-packages

#---------
# GTKWave
#---------
RUN apt-get install -y gtkwave=3.3.121-1

#---------------
# Miscellaneous
#---------------

WORKDIR /home/adventoffpga
