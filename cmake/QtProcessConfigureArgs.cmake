# This script reads Qt configure arguments from config.opt,
# translates the arguments to CMake arguments and calls CMake.
#
# This file is to be used in CMake script mode with the following variables set:
# OPTFILE: A text file containing the options that were passed to configure
#          with one option per line.

cmake_policy(SET CMP0007 NEW)

set(cmake_args "")
macro(push)
    list(APPEND cmake_args ${ARGN})
endmacro()

macro(calculate_state)
    set(state ON)
    if(CMAKE_MATCH_1 MATCHES "no-?")
        set(state OFF)
    endif()
endmacro()

macro(pop_path_argument)
    list(POP_FRONT configure_args path)
    string(REGEX REPLACE "^\"(.*)\"$" "\\1" path "${path}")
    file(TO_CMAKE_PATH "${path}" path)
endmacro()

get_filename_component(source_dir ".." ABSOLUTE BASE_DIR "${CMAKE_CURRENT_LIST_DIR}")
file(STRINGS "${OPTFILE}" configure_args)
list(FILTER configure_args EXCLUDE REGEX "^[ \t]*$")
list(TRANSFORM configure_args STRIP)
unset(generator)
set(auto_detect_generator TRUE)
while(configure_args)
    list(POP_FRONT configure_args arg)
    if(arg STREQUAL "-cmake")
        # ignore
    elseif(arg STREQUAL "-cmake-generator")
        list(POP_FRONT configure_args generator)
    elseif(arg STREQUAL "-cmake-use-default-generator")
        set(auto_detect_generator FALSE)
    elseif(arg STREQUAL "-top-level")
        get_filename_component(source_dir "../.." ABSOLUTE BASE_DIR "${CMAKE_CURRENT_LIST_DIR}")
    elseif(arg STREQUAL "-skip")
        list(POP_FRONT configure_args qtrepo)
        push("-DBUILD_${qtrepo}=OFF")
    elseif(arg STREQUAL "-opensource")
        # to be done
    elseif(arg STREQUAL "-commercial")
        # to be done
    elseif(arg STREQUAL "-confirm-license")
        # to be done
    elseif(arg MATCHES "^-(no)?make")
        calculate_state()
        list(POP_FRONT configure_args component)
        if(component STREQUAL "tests")
            push(-DBUILD_TESTING=${state})
        elseif(component STREQUAL "examples")
            push(-DBUILD_EXAMPLES=${state})
        else()
            string(TOUPPER "${component}" uc_component)
            push(-DQT_NO_MAKE_${uc_component}=${state})
        endif()
    elseif(arg MATCHES "^-(no-)?feature")
        calculate_state()
        list(POP_FRONT configure_args feature)
        push("-DFEATURE_${feature}=${state}")
    elseif(arg MATCHES "^-(no-)pch")
        calculate_state()
        push("-DBUILD_WITH_PCH=${state}")
    elseif(arg MATCHES "^-system-(.*)")
        list(POP_FRONT configure_args lib)
        push("-DFEATURE_system_${lib}=ON")
    elseif(arg MATCHES "^-qt-(.*)")
        list(POP_FRONT configure_args lib)
        push("-DFEATURE_system_${lib}=OFF")
    elseif(arg MATCHES "^-sanitize=(.*)")
        push("-DECM_ENABLE_SANITIZERS=${CMAKE_MATCH_1}")
    elseif(arg STREQUAL "-ccache")
        push(-DQT_USE_CCACHE=ON)
    elseif(arg STREQUAL "-developer-build")
        push(-DFEATURE_developer_build=ON)
    elseif(arg STREQUAL "-prefix")
        pop_path_argument()
        push("-DCMAKE_INSTALL_PREFIX=${path}")
    elseif(arg STREQUAL "-extprefix")
        pop_path_argument()
        push("-DCMAKE_STAGING_PREFIX=${path}")
    elseif(arg STREQUAL "-hostprefix")
        message(FATAL_ERROR "${arg} is not supported in the CMake build.")
    elseif(arg STREQUAL "-external-hostbindir")
        # This points to the bin directory of the Qt installation.
        # This can be multiple levels deep and we cannot deduce the QT_HOST_PATH safely.
        message(FATAL_ERROR "${arg} is not supported anymore. Use -qt-host-path <dir> instead.")
    elseif(arg STREQUAL "-qt-host-path")
        pop_path_argument()
        push("-DQT_HOST_PATH=${path}")
    elseif(arg STREQUAL "--")
        # Everything after this argument will be passed to CMake verbatim.
        push(${configure_args})
        break()
    else()
        message(FATAL_ERROR "Unknown configure argument: ${arg}")
    endif()
endwhile()

if(NOT generator AND auto_detect_generator)
    find_program(ninja ninja)
    if(ninja)
        set(generator Ninja)
    else()
        if(CMAKE_HOST_UNIX)
            set(generator "Unix Makefiles")
        elseif(CMAKE_HOST_WINDOWS)
            find_program(msvc_compiler cl.exe)
            if(msvc_compiler)
                set(generator "NMake Makefiles")
                find_program(jom jom)
                if(jom)
                    string(APPEND generator " JOM")
                endif()
            else()
                set(generator "MinGW Makefiles")
            endif()
        endif()
    endif()
endif()
if(generator)
    push(-G "${generator}")
endif()

push("${source_dir}")

execute_process(COMMAND "${CMAKE_COMMAND}" ${cmake_args}
    COMMAND_ECHO STDOUT
    RESULT_VARIABLE exit_code)
if(NOT exit_code EQUAL 0)
    message(FATAL_ERROR "CMake exited with code ${exit_code}.")
endif()
