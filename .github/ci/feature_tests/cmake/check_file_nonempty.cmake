# Assert that a build artefact exists and is not empty.
#
# Usage:
#   cmake -DFILE=<path> [-DMIN_SIZE=<bytes>] -P check_file_nonempty.cmake

if(NOT DEFINED FILE)
  message(FATAL_ERROR "check_file_nonempty: -DFILE=<path> is required")
endif()

if(NOT DEFINED MIN_SIZE)
  set(MIN_SIZE 1)
endif()

if(NOT EXISTS "${FILE}")
  message(FATAL_ERROR "check_file_nonempty: file was not generated: ${FILE}")
endif()

file(SIZE "${FILE}" _size)
if(_size LESS MIN_SIZE)
  message(FATAL_ERROR
    "check_file_nonempty: ${FILE} is ${_size} bytes, expected >= ${MIN_SIZE}")
endif()

message(STATUS "check_file_nonempty: OK — ${FILE} (${_size} bytes)")
