# Additional clean files
cmake_minimum_required(VERSION 3.16)

if("${CONFIG}" STREQUAL "" OR "${CONFIG}" STREQUAL "Debug")
  file(REMOVE_RECURSE
  "CMakeFiles\\MySerial_Gemini_autogen.dir\\AutogenUsed.txt"
  "CMakeFiles\\MySerial_Gemini_autogen.dir\\ParseCache.txt"
  "MySerial_Gemini_autogen"
  )
endif()
