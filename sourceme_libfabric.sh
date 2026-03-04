export ROOT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd -P )
echo "ROOT_DIR = "$ROOT_DIR

# This is an attempt to avoid using the USER variable to determine the system configuration, which is not a good practice. Instead, we can check for specific environment variables or modules that are unique to each system.
detect_system_config() {
    # Method 1: Check for Cray environment
    if [[ -n "$CRAY_MPICH_VER" || -n "$PE_ENV" ]]; then
        if [[ -n "$ROCM_PATH" ]] || module avail rocm &>/dev/null; then
            echo "cray_rocm"  # Cray with ROCm (like lazzaroa config)
		elif [[ -n $NCCL_PATH ]]; then
			echo "cray_nccl"  # Cray with NCCL (hypothetical)
        else
            echo "cray_generic"
        fi
        return
    fi
    
    # Method 2: Check for NRIS environment  
    if module avail NRIS/GPU &>/dev/null; then
        echo "nris"  # NRIS system (like marcink config)
        return
    fi
    
    # Method 3: Check for pre-installed libfabric
    if [[ -d "/opt/cray/libfabric" ]]; then
        echo "cray_preinstalled"
        return
    fi
    
    # Method 4: Fallback to generic
    echo "generic"
}

SYSTEM_CONFIG=$(detect_system_config)

case "$SYSTEM_CONFIG" in
    "cray_rocm")
        # This was the lazzaroa configuration
		module load PrgEnv-gnu
		module load rocm
		module list

		echo "ROCM_PATH = "$ROCM_PATH

		XPMEM_ROOT=$(pkg-config --variable=libdir cray-xpmem)
		XPMEM_LIBFABRIC="--enable-xpmem=${XPMEM_ROOT}"
		echo "XPMEM Lib path  = "$XPMEM_ROOT

		GPU_INCLUDE="-I$ROCM_PATH/include"
		GPU_LIBFABRIC="--with-rocr=$ROCM_PATH"
        ;;
    "nris"|"cray_preinstalled") 
        # This was the marcink configuration
		if [ "${CRAY_MPICH_VER}" == "" ]; then
			ml load NRIS/GPU
			ml load libfabric/2.3.1-GCCcore-14.3.0
			return 0
		fi
		# with cray mpi use the pre-installed libfabric
		export PREFIX_LIBFABRIC=/opt/cray/libfabric/1.22.0/
		return 0
        ;;
    "generic")
        # Default configuration
		echo "System not recognized"
		return -1
        ;;
esac

export PREFIX_CXI=$ROOT_DIR/install_cxi # installation directory
export PREFIX_LIBFABRIC=$ROOT_DIR/install_libfabric # installation directory
export LIBFABRIC_DIR=$ROOT_DIR/libfabric
export LIBCXI_DIR=$LIBFABRIC_DIR/libcxi

export c=gnu
export CC=gcc-14
export CFLAGS="-g -O -Wno-error=maybe-uninitialized -I$PREFIX_CXI/include $GPU_INCLUDE"
export CPPFLAGS="-I$PREFIX_CXI/include $GPU_INCLUDE"

export CXX=g++-14
export CXXFLAGS="-g -O -I$PREFIX_CXI/include $GPU_INCLUDE"

export FC=gfortran-14
export FCFLAGS="-O -I$PREFIX_CXI/include $GPU_INCLUDE"

export LDFLAGS="-g -O -L$PREFIX_CXI/lib -L$ROCM_PATH/lib"

export PATH=${PREFIX_CXI}/bin:${PATH}
export LD_LIBRARY_PATH=${PREFIX_CXI}/lib:${LD_LIBRARY_PATH}
export PKG_CONFIG_PATH=$PREFIX_CXI/lib/pkgconfig:$PKG_CONFIG_PATH
export MANPATH=$PREFIX_CXI/man:$MANPATH

export PATH=${PREFIX_LIBFABRIC}/bin:${PATH}
export LD_LIBRARY_PATH=${PREFIX_LIBFABRIC}/lib:${LD_LIBRARY_PATH}
export PKG_CONFIG_PATH=$PREFIX_LIBFABRIC/lib/pkgconfig:$PKG_CONFIG_PATH
export MANPATH=$PREFIX_LIBFABRIC/man:$MANPATH
