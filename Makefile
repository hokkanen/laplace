default: build
	echo "Start Build"

# Accelerator architecture
ifeq ($(HOST),1)

CXX = g++
CXXFLAGS = -g -O3
EXE = bin.host

else ifeq ($(HIP),CUDA)

CXX = hipcc
CXXDEFS = -DHAVE_HIP
CXXFLAGS = -g -O3 -Xcompiler -fopt-info-loop --x=cu --extended-lambda
# CXXFLAGS = -g -O3 -Xcompiler -fno-tree-vectorize -Xcompiler -fopt-info-loop --x=cu --extended-lambda
EXE = bin.hip.cuda

else ifeq ($(HIP),ROCM)

CXX = hipcc
CXXDEFS = -DHAVE_HIP
CXXFLAGS = -g -O3
EXE = bin.hip.rocm

else ifeq ($(KOKKOS),CUDA)

# Inputs for Makefile.kokkos
# see https://github.com/kokkos/kokkos/wiki/Compiling
KOKKOS_PATH = $(shell pwd)/kokkos
CXX = ${KOKKOS_PATH}/bin/nvcc_wrapper
CXXFLAGS = -g -O3
KOKKOS_DEVICES = "Cuda"
KOKKOS_ARCH = "Volta70"
KOKKOS_CUDA_OPTIONS = "enable_lambda,force_uvm"
include $(KOKKOS_PATH)/Makefile.kokkos
# Other
CXXDEFS = -DHAVE_KOKKOS
EXE = bin.kokkos.cuda
CLEAN = kokkos-clean

else ifeq ($(KOKKOS),ROCM)

# Inputs for Makefile.kokkos
# see https://github.com/kokkos/kokkos/wiki/Compiling
KOKKOS_PATH = $(shell pwd)/kokkos
CXX = hipcc
CXXFLAGS = -g -O3
KOKKOS_DEVICES = "HIP"
KOKKOS_ARCH = "VEGA908"
include $(KOKKOS_PATH)/Makefile.kokkos
# Other
CXXDEFS = -DHAVE_KOKKOS
EXE = bin.kokkos.rocm
CLEAN = kokkos-clean

else

CXX = nvcc
CXXDEFS = -DHAVE_CUDA
CXXFLAGS = -g -O3 --x=cu --extended-lambda
EXE = bin.cuda

endif

# Message passing protocol
ifeq ($(MPI),1)

MPICXX = mpicxx
MPICXXENV = OMPI_CXXFLAGS='' OMPI_CXX='$(CXX) -DHAVE_MPI $(CXXDEFS) $(CXXFLAGS)'
LDFLAGS = -L/appl/spack/install-tree/gcc-9.1.0/openmpi-4.1.1-vonyow/lib
LIBS = -lmpi

else

MPICXX = $(CXX)
MPICXXFLAGS = $(CXXDEFS) $(CXXFLAGS)

endif

SRC_PATH = src/
SOURCES = $(shell ls src/*.cpp)

OBJ_PATH = src/
OBJECTS = $(shell for file in $(SOURCES);\
		do echo -n $$file | sed -e "s/\(.*\)\.cpp/\1\.o/";echo -n " ";\
		done)

build: $(EXE)

depend:
	makedepend $(CXXDEFS) -m $(SOURCES)

test: $(EXE)
	./$(EXE)

# KOKKOS_DEFINITIONS are outputs from Makefile.kokkos 
# see https://github.com/kokkos/kokkos/wiki/Compiling
$(EXE): $(OBJECTS) $(KOKKOS_LINK_DEPENDS)
	$(CXX) $(LDFLAGS) $(OBJECTS) $(LIBS) $(KOKKOS_LDFLAGS) $(KOKKOS_LIBS) -o $(EXE)

clean: $(CLEAN)
	rm -f $(OBJECTS) *.cuda *.hip.* *.host *.kokkos.* Kokkos* libkokkos.a *.o

# Compilation rules
$(OBJ_PATH)%.o: $(SRC_PATH)%.cpp $(KOKKOS_CPP_DEPENDS)
	$(MPICXXENV) $(MPICXX) $(MPICXXFLAGS) $(KOKKOS_CPPFLAGS) $(KOKKOS_CXXFLAGS) -c $< -o $(SRC_PATH)$(notdir $@)

# DO NOT DELETE

src/main.o: src/devices_kokkos.h
