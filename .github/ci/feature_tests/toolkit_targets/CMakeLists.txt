cmake_minimum_required(VERSION 3.20)

# Covers the imported targets created by FindHGGCToolkit: every documented
# HGGC::* target is checked, and for the ones present the target properties are
# validated (IMPORTED_LOCATION points at a real file, propagated include dir
# really contains the documented header).
#
# HGGC::hgjpeg is included here on purpose — test/CMakeLists.txt only prints a
# hand-written target list that omits it.
#
# Standalone run:
#   cmake -DCMAKE_MODULE_PATH=/path/to/cmake-hgcc/cmake/Modules -S . -B build

project(hggc_toolkit_targets LANGUAGES CXX HG)

find_package(HGGCToolkit REQUIRED)

# Targets that any usable SDK must provide. Kept deliberately small: trimmed SDK
# flavours legitimately ship without the math/codec/communication libraries.
set(_required_targets toolkit hggcrt hggc)

# <target>=<documented header>, empty header means the target carries no include
# directory (see FindHGGCToolkit.cmake).
set(_all_targets
  "hggcrt=hggc_runtime.h"
  "hggc="
  "hgrtc=hgrtc.h"
  "hgrtc_builtins="
  "hgvm=hgvm.h"
  "hgJitLink=hgJitLink.h"
  "hgJitLink_static="
  "acblas=acblas.h"
  "acblasLt=acblasLt.h"
  "acfft=acfft.h"
  "acrand=acrand.h"
  "acdnn=acdnn.h"
  "acsparse=acsparse.h"
  "acsolver=acsolverDn.h"
  "hgjpeg=hgjpeg.h"
  "pccl=pccl.h")

set(_missing "")
set(_present "")
set(_errors "")

foreach(_entry IN LISTS _all_targets)
  string(REPLACE "=" ";" _parts "${_entry}")
  list(GET _parts 0 _lib)
  list(LENGTH _parts _n)
  set(_header "")
  if(_n GREATER 1)
    list(GET _parts 1 _header)
  endif()

  if(NOT TARGET HGGC::${_lib})
    list(APPEND _missing ${_lib})
    continue()
  endif()
  list(APPEND _present ${_lib})

  get_target_property(_loc HGGC::${_lib} IMPORTED_LOCATION)
  if(NOT _loc)
    list(APPEND _errors "HGGC::${_lib}: IMPORTED_LOCATION is not set")
  elseif(NOT EXISTS "${_loc}")
    list(APPEND _errors "HGGC::${_lib}: IMPORTED_LOCATION does not exist: ${_loc}")
  endif()

  if(NOT _header STREQUAL "")
    get_target_property(_incs HGGC::${_lib} INTERFACE_INCLUDE_DIRECTORIES)
    if(NOT _incs)
      list(APPEND _errors "HGGC::${_lib}: INTERFACE_INCLUDE_DIRECTORIES is not set")
    else()
      set(_found_header FALSE)
      foreach(_inc IN LISTS _incs)
        if(EXISTS "${_inc}/${_header}")
          set(_found_header TRUE)
          break()
        endif()
      endforeach()
      if(NOT _found_header)
        list(APPEND _errors
          "HGGC::${_lib}: ${_header} not found in propagated include dirs: ${_incs}")
      endif()
    endif()
  endif()
endforeach()

# HGGC::toolkit is an interface target: no IMPORTED_LOCATION, but it must
# aggregate the runtime libraries and propagate the include directory.
if(NOT TARGET HGGC::toolkit)
  list(APPEND _errors "HGGC::toolkit was not created")
else()
  get_target_property(_tk_libs HGGC::toolkit INTERFACE_LINK_LIBRARIES)
  get_target_property(_tk_incs HGGC::toolkit INTERFACE_INCLUDE_DIRECTORIES)
  if(NOT _tk_libs)
    list(APPEND _errors "HGGC::toolkit: INTERFACE_LINK_LIBRARIES is empty")
  endif()
  if(NOT _tk_incs OR NOT EXISTS "${_tk_incs}/hggc_runtime.h")
    list(APPEND _errors
      "HGGC::toolkit: INTERFACE_INCLUDE_DIRECTORIES does not provide hggc_runtime.h (${_tk_incs})")
  endif()
  message(STATUS "HGGC::toolkit links: ${_tk_libs}")
endif()

message(STATUS "SDK root:      ${HGGCToolkit_ROOT}")
message(STATUS "SDK version:   ${HGGCToolkit_VERSION}")
message(STATUS "targets found: ${_present}")
message(STATUS "targets absent: ${_missing}")

foreach(_lib IN LISTS _required_targets)
  if(NOT TARGET HGGC::${_lib})
    list(APPEND _errors "required target HGGC::${_lib} is missing")
  endif()
endforeach()

if(_errors)
  string(REPLACE ";" "\n  " _msg "${_errors}")
  message(FATAL_ERROR "imported target validation failed:\n  ${_msg}")
endif()

message(STATUS "imported target validation passed")
