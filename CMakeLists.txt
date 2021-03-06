cmake_minimum_required(VERSION 3.0)
project(toolbox
        VERSION 3.2.2
        DESCRIPTION "Toolbox - C++ helpers, especially for string and bytes handling")
set(CMAKE_CXX_STANDARD 11)

if (NOT CMAKE_BUILD_TYPE)
	set(CMAKE_BUILD_TYPE Release)
endif ()

list(APPEND CMAKE_MODULE_PATH ${CMAKE_CURRENT_SOURCE_DIR}/modules)
if (WIN32)
	execute_process(COMMAND cmd /C "echo ${CMAKE_PROJECT_VERSION} > ${CMAKE_CURRENT_SOURCE_DIR}/version")
else ()
	execute_process(COMMAND bash -c "echo ${CMAKE_PROJECT_VERSION} > ${CMAKE_CURRENT_SOURCE_DIR}/version")
endif ()


add_definitions(/D_CRT_SECURE_NO_WARNINGS=1)
include(modules/compilers_flags.cmake)

option(ENABLE_CONAN "Enable dependency manager" On)
option(ENABLE_SHARED "Build shared library" Off)
option(ENABLE_TEST "Build test target" Off)

if (MSVC)
	set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} /W2 /MP")
	set(CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_DEBUG} /DEBUG /Od")
	set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} /O2")
	string(REGEX REPLACE "\\/W3" " " CMAKE_CXX_FLAGS ${CMAKE_CXX_FLAGS})
	add_compile_options(/wd4068)
	add_compile_options(/wd4319)
	add_compile_options(/wd4251)
	add_compile_options(/wd4275)
elseif (MINGW)
	set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wall -fPIC -Wno-unknown-pragmas -Wno-shift-count-overflow")
	set(CMAKE_CXX_FLAGS_DEBUG "-g -O0")
	set(CMAKE_CXX_FLAGS_RELEASE "-O3")
else ()
	#-fvisibility=hidden
	set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wall -fPIC -Wextra -pedantic -Wno-unknown-pragmas -Wno-unused-parameter")
	set(CMAKE_CXX_FLAGS_DEBUG "-g -O0")
	set(CMAKE_CXX_FLAGS_RELEASE "-O3")
endif ()

set(TOOLBOX_EXPORTING 1)
if (ENABLE_SHARED)
	set(TOOLBOX_SHARED 1)
endif ()


include(SystemDetector)
include(options.cmake)

if (NOT HAVE_REGEX_H)
	message(STATUS "Trying to use Boost.Regex as your compiler does not support it")
	if (ENABLE_CONAN)
		set(HAVE_REGEX_H 1)
		set(HAVE_BOOST_REGEX 1)
	else ()
		set(Boost_DEBUG OFF)
		set(Boost_USE_MULTITHREADED ON)

		if (WIN32)
			find_package(Boost)
		else ()
			find_package(Boost COMPONENTS regex)
		endif ()

		if (Boost_FOUND)
			set(HAVE_REGEX_H 1)
			set(HAVE_BOOST_REGEX 1)
		endif ()
	endif ()
endif ()
configure_file(${CMAKE_CURRENT_SOURCE_DIR}/cfg/toolbox_config.h.in ${CMAKE_CURRENT_SOURCE_DIR}/include/toolbox/toolbox_config.h)

set(MULTI_HEADERS
    include/toolbox/toolbox_config.h
    include/toolbox/data.hpp
    include/toolbox/data/bytes_data.h
    include/toolbox/data/bytes_buffer.h
    include/toolbox/data/utils.h
    include/toolbox/data/literals.h
    include/toolbox/strings.hpp
    include/toolbox/strings/regex.h
    include/toolbox/term.h
    include/toolbox/log.h
    include/toolbox/io.h
    include/toolbox/strings/decimal_formatter.h
    include/toolbox/time_profiler.h
    include/toolbox/collections.h
    include/toolbox/data/base64.h
    include/toolbox/data/basic_data.h
    include/toolbox/data/bytes_array.h
    include/toolbox/data/transformers.h
    )

set(MULTI_SOURCES
    ${MULTI_HEADERS}
    src/data/bytes_data.cpp
    src/data/bytes_data.cpp
    src/data/bytes_buffer.cpp
    src/data/utils.cpp
    src/strings.cpp
    src/strings/regex.cpp
    src/io.cpp
    src/strings/decimal_formatter.cpp
    src/term.cpp
    src/log.cpp
    src/time_profiler.cpp
    src/data/base64.cpp
    )

if (ENABLE_SHARED)
	message(STATUS "Build shared library")
	add_library(${PROJECT_NAME} SHARED ${MULTI_SOURCES})
	set_property(TARGET ${PROJECT_NAME} PROPERTY
	             MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>DLL")
else ()
	add_library(${PROJECT_NAME} STATIC ${MULTI_SOURCES})
	set_property(TARGET ${PROJECT_NAME} PROPERTY
	             MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")
endif ()

message(STATUS "Build Type: ${CMAKE_BUILD_TYPE}")
message(STATUS "CXX_FLAGS:         ${CMAKE_CXX_FLAGS}")
message(STATUS "CXX_DBG_FLAGS:     ${CMAKE_CXX_FLAGS_DEBUG}")
message(STATUS "CXX_REL_FLAGS:     ${CMAKE_CXX_FLAGS_RELEASE}")
message(STATUS "CXX_MINSIZE_FLAGS: ${CMAKE_CXX_FLAGS_MINSIZEREL}")
message(STATUS "CXX_RELDBG_FLAGS:  ${CMAKE_CXX_FLAGS_RELWITHDEBINFO}")

target_include_directories(${PROJECT_NAME} PUBLIC
                           $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
                           $<INSTALL_INTERFACE:include>
                           )

if (ENABLE_CONAN)
	include(ConanInit)
	conan_init()
endif ()

message(STATUS "Enable conan: ${ENABLE_CONAN}")

if (NOT HAVE_STD_REGEX)
	message(STATUS "Using Boost.Regex as your compiler does not support it")
	if (ENABLE_CONAN)
		target_link_libraries(${PROJECT_NAME} CONAN_PKG::boost)
	elseif (Boost_FOUND)
		target_link_libraries(${PROJECT_NAME} Boost::regex)
	else ()
		if (TOOLBOX_PACKAGING)
			message(FATAL_ERROR "To build full package version of toolbox you must install Boost.Regex to your system")
		endif ()
		message(WARNING "Boost not found on your system. Disabled \"regex\"-based functionality")
	endif ()
endif ()

if (ENABLE_TEST)
	if (NOT ENABLE_CONAN)
		add_subdirectory(${CMAKE_CURRENT_SOURCE_DIR}/libs/googletest)
		add_library(CONAN_PKG::gtest ALIAS gtest)
	endif ()
	set(gtest_force_shared_crt ${ENABLE_SHARED} CACHE BOOL "" FORCE)

	if (APPLE)
		add_definitions(-DGTEST_USE_OWN_TR1_TUPLE)
		add_definitions(-D__GLIBCXX__)
	endif ()

	enable_testing()
	add_definitions(-DTOOLBOX_TESTING=1)

	add_executable(${PROJECT_NAME}-test
	               tests/main.cpp
	               tests/term_test.cpp
	               tests/filesystem_test.cpp
	               tests/numbers_test.cpp
	               tests/collection_test.cpp
	               tests/strings_test.cpp
	               tests/data_test.cpp
	               tests/bytes_benchmark.cpp)

	if (ENABLE_PVS)
		include(PVS-Studio)
		pvs_studio_add_target(TARGET ${PROJECT_NAME}.analyze ALL
		                      OUTPUT FORMAT errorfile
		                      CONFIG ${CMAKE_CURRENT_SOURCE_DIR}/pvs.cfg
		                      ANALYZE ${PROJECT_NAME}-test
		                      SOURCES ${CMAKE_CURRENT_SOURCE_DIR}/include
		                      LOG target.err)
	endif ()

	if (NOT MSVC)
		target_compile_options(${PROJECT_NAME}-test PRIVATE -Wno-missing-field-initializers)
	endif ()
	target_link_libraries(${PROJECT_NAME}-test CONAN_PKG::gtest)
	target_link_libraries(${PROJECT_NAME}-test ${PROJECT_NAME})

	if (WITH_COVERAGE)
		set(COVERAGE_LCOV_EXCLUDES
		    'libs/*'
		    '/usr/include/*'
		    'tests/*'
		    'boost/*'
		    '/usr/include/*'
		    '/usr/local/*'
		    'v1'
		    '4.9'
		    )
		include(modules/CodeCoverage.cmake)
		append_coverage_compiler_flags()
		setup_target_for_coverage_lcov(
			NAME ${PROJECT_NAME}-coverage
			EXECUTABLE ${PROJECT_NAME}-test
			DEPENDENCIES ${PROJECT_NAME}-test
		)
	endif ()

	add_test(NAME test-all COMMAND ${CMAKE_CURRENT_BINARY_DIR}/bin/${PROJECT_NAME}-test)

endif ()

include(package)
