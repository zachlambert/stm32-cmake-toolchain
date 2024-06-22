cmake_minimum_required(VERSION 3.3)
project(stm32-cmake-toolchain)

cmake_policy(SET CMP0076 NEW)


if (NOT DEFINED MCU_NAME)
    message(FATAL_ERROR "Must set microcontroller name with -DMCU_NAME=...")
endif()

if (NOT DEFINED ROOT_PATH)
    set(ROOT_PATH /opt/stm32-collection)
endif()

if (NOT DEFINED SPECS)
    set(SPECS nosys.specs)
endif()

if (NOT DEFINED NOSTARTFILES)
    set(NOSTARTFILES TRUE)
endif()

if (NOT DEFINED ENABLE_ERROR_HANDLING)
    set(ENABLE_ERROR_HANDLING FALSE)
endif()


set(LIB_PATH ${ROOT_PATH}/${MCU_NAME}/lib)
set(CMAKE_CONFIG_PATH ${ROOT_PATH}/${MCU_NAME}/cmake)
set(INCLUDE_PATH ${ROOT_PATH}/${MCU_NAME}/include)
set(TOOLCHAIN_PATH ${ROOT_PATH}/toolchain)

set(SCRIPTS_PATH ${CMAKE_CURRENT_LIST_DIR}/scripts)
set(DEVICES_DATA ${CMAKE_CURRENT_LIST_DIR}/files/devices.data)

execute_process(COMMAND
    python3
    ${SCRIPTS_PATH}/genlink.py ${DEVICES_DATA} ${MCU_NAME} FAMILY
    OUTPUT_VARIABLE genlink_family)
execute_process(COMMAND
    python3
    ${SCRIPTS_PATH}/genlink.py ${DEVICES_DATA} ${MCU_NAME} SUBFAMILY
    OUTPUT_VARIABLE genlink_subfamily)
execute_process(COMMAND
    python3
    ${SCRIPTS_PATH}/genlink.py ${DEVICES_DATA} ${MCU_NAME} CPU
    OUTPUT_VARIABLE genlink_cpu)
execute_process(COMMAND
    python3
    ${SCRIPTS_PATH}/genlink.py ${DEVICES_DATA} ${MCU_NAME} FPU
    OUTPUT_VARIABLE genlink_fpu)
execute_process(COMMAND
    python3
    ${SCRIPTS_PATH}/genlink.py ${DEVICES_DATA} ${MCU_NAME} CPPFLAGS
    OUTPUT_VARIABLE genlink_cpp_flags)
execute_process(COMMAND
    python3
    ${SCRIPTS_PATH}/genlink.py ${DEVICES_DATA} ${MCU_NAME} DEFS
    OUTPUT_VARIABLE genlink_defs_str)
separate_arguments(genlink_defs UNIX_COMMAND ${genlink_defs_str})

set(LINKER_SCRIPT_TEMPLATE ${CMAKE_CURRENT_LIST_DIR}/files/linker.ld.S)
set(LINKER_SCRIPT ${CMAKE_CURRENT_BINARY_DIR}/linker.ld)
set(LINKER_SCRIPT_INSTALL ${TOOLCHAIN_PATH}/ld/${MCU_NAME}.ld)

add_custom_command(
    OUTPUT ${LINKER_SCRIPT}
    COMMAND
        ${CMAKE_CXX_COMPILER}
        ${genlink_defs} -P
        -E ${LINKER_SCRIPT_TEMPLATE}
        -o ${LINKER_SCRIPT}
    COMMAND
        python3
        ${CMAKE_CURRENT_LIST_DIR}/scripts/fix_linker.py
        ${ENABLE_ERROR_HANDLING}
        ${LINKER_SCRIPT}
    DEPENDS
        ${LINKER_SCRIPT_TEMPLATE}
        ${DEVICES_DATA}
    COMMENT "Generating linker script"
)
add_custom_target(linker_script ALL DEPENDS ${LINKER_SCRIPT})


# Define ARCH_FLAGS

set(ARCH_FLAGS -mcpu=${genlink_cpu})

set(MTHUMB_LIST "cortex-m0;cortex-m0plus;cortex-m3;cortex-m4;cortex-m7")
if(${genlink_cpu} IN_LIST MTHUMB_LIST)
    list(APPEND ARCH_FLAGS -mthumb)
endif()

if(${genlink_fpu} STREQUAL "soft")
    list(APPEND ARCH_FLAGS -msoft-float)
elseif(${genlink_fpu} STREQUAL "hard-fpv4-sp-d16")
    list(APPEND ARCH_FLAGS -mfloat-abi=hard -mfpu=fpv4-sp-d16)
elseif(${genlink_fpu} STREQUAL "hard-fpv5-sp-d16")
    list(APPEND ARCH_FLAGS -mfloat-abi=hard -mfpu=fpv5-sp-d16)
else()
    message(FATAL_ERROR "Unrecognised fpu type ${genlink_fpu}")
endif()

# Define compiler flags

# C and CXX
separate_arguments(TGT_CPPFLAGS UNIX_COMMAND ${genlink_cpp_flags})
list(APPEND TGT_CPPFLAGS ${ARCH_FLAGS})
list(APPEND TGT_CPPFLAGS -MD -Wall -Wundef)
# C
set(TGT_CFLAGS ${OS} -std=c99 -ggdb3 ${ARCH_FLAGS})
list(APPEND TGT_CFLAGS -fno-common)
list(APPEND TGT_CFLAGS -ffunction-sections -fdata-sections)
list(APPEND TGT_CFLAGS -Wextra -Wno-unused-variables -Wimplicit-function-declaration)
list(APPEND TGT_CFLAGS -Wredundant-decls -Wstrict-prototypes -Wmissing-prototypes)
# C++
set(TGT_CXXFLAGS ${OS} -ggdb3 ${ARCH_FLAGS})
list(APPEND TGT_CXXFLAGS -fno-common)
list(APPEND TGT_CXXFLAGS -ffunction-sections -fdata-sections)
list(APPEND TGT_CXXFLAGS -Wextra -Wredundant-decls)

# Define linker flags

set(TGT_LDFLAGS ${ARCH_FLAGS})
list(APPEND TGT_LDFLAGS -specs=${SPECS} -Wl,--gc-sections)
list(APPEND TGT_LDFLAGS -Wl,-Map=${target}.map -Wl,--start-group)
list(APPEND TGT_LDFLAGS -lc -lgcc -Wl,--end-group)
if(${NOSTARTFILES})
    list(APPEND TGT_LDFLAGS -nostartfiles)
endif()
list(APPEND TGT_LDFLAGS -T${INSTALL_LINKER_SCRIPT})


# Create toolchain file

set(TOOLCHAIN_FILE_TEMPLATE ${CMAKE_CURRENT_LIST_DIR}/toolchain.cmake)
set(TOOLCHAIN_FILE ${CMAKE_CURRENT_BINARY_DIR}/toolchain.cmake)
configure_file(${TOOLCHAIN_FILE_TEMPLATE} ${TOOLCHAIN_FILE} @ONLY)


# Install

install(
    FILES ${TOOLCHAIN_FILE}
    DESTINATION ${TOOLCHAIN_PATH}
    RENAME ${MCU_NAME}.cmake
)

install(
    FILES ${LINKER_SCRIPT}
    DESTINATION ${TOOLCHAIN_PATH}/ld
    RENAME ${MCU_NAME}.ld
)
