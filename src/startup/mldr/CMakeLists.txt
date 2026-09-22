project(mldr)

cmake_minimum_required(VERSION 3.13)

# Auto-detect Android (Termux) if the variable is not already set:
# when CMAKE_SYSTEM_NAME is "Linux" and the sysroot/linker reference bionic
# or libandroid-posix-semaphore is available, we are almost certainly on Android.
if (NOT DEFINED ANDROID)
	if (EXISTS "/system/lib64/libc.so" OR EXISTS "/system/lib/libc.so")
		set(ANDROID TRUE)
		message(STATUS "mldr: Android detected automatically (bionic libc present). Use -DANDROID=FALSE to override.")
	endif()
endif()

include_directories(include)

set_source_files_properties(${CMAKE_BINARY_DIR}/src/external/darlingserver/src/rpc.c PROPERTIES
	GENERATED TRUE
)

add_library(mldr_dserver_rpc STATIC ${CMAKE_BINARY_DIR}/src/external/darlingserver/src/rpc.c)

add_dependencies(mldr_dserver_rpc generate_dserver_rpc_wrappers)

target_compile_options(mldr_dserver_rpc PRIVATE -include ${CMAKE_CURRENT_SOURCE_DIR}/resources/dserver-rpc-defs.h)
add_dependencies(mldr_dserver_rpc rtsig_h)
target_include_directories(mldr_dserver_rpc PRIVATE ${CMAKE_CURRENT_BINARY_DIR}/..)

set(mldr_sources
	mldr.c
	commpage.c
	elfcalls/elfcalls.c
	elfcalls/threads.c
)

add_executable(mldr ${mldr_sources})

target_compile_options(mldr PRIVATE -pthread)
target_link_options(mldr PRIVATE -pthread)

if (ANDROID)
	find_library(ANDROID_POSIX_SEMAPHORE_LIB android-posix-semaphore)
	target_link_libraries(mldr PRIVATE -ldl mldr_dserver_rpc -lm)
	if (ANDROID_POSIX_SEMAPHORE_LIB)
		target_link_libraries(mldr PRIVATE ${ANDROID_POSIX_SEMAPHORE_LIB})
	endif()
	set_target_properties(mldr PROPERTIES
		INSTALL_RPATH "${CMAKE_INSTALL_PREFIX}/lib"
		BUILD_WITH_INSTALL_RPATH TRUE
	)
else()
	target_link_libraries(mldr PRIVATE -lrt -ldl mldr_dserver_rpc -lm)
endif()

install(TARGETS mldr DESTINATION libexec/darling/usr/libexec/darling)
install(PROGRAMS $<TARGET_FILE:mldr> DESTINATION libexec/darling/bin)

configure_file(darling.conf.in darling.conf @ONLY)
install(FILES "${CMAKE_CURRENT_BINARY_DIR}/darling.conf" DESTINATION lib/binfmt.d)

if (BUILD_TARGET_32BIT)
	add_library(mldr32_dserver_rpc STATIC ${CMAKE_BINARY_DIR}/src/external/darlingserver/src/rpc.c)
	add_dependencies(mldr32_dserver_rpc generate_dserver_rpc_wrappers)
	target_compile_options(mldr32_dserver_rpc PRIVATE -include ${CMAKE_CURRENT_SOURCE_DIR}/resources/dserver-rpc-defs.h)
	target_compile_options(mldr32_dserver_rpc PRIVATE -m32)
	target_link_options(mldr32_dserver_rpc PRIVATE -m32)
	add_dependencies(mldr32_dserver_rpc rtsig_h)
	target_include_directories(mldr32_dserver_rpc PRIVATE ${CMAKE_CURRENT_BINARY_DIR}/..)

	add_executable(mldr32 ${mldr_sources})
	target_compile_options(mldr32 PRIVATE -m32)
	target_link_options(mldr32 PRIVATE -m32)
	target_compile_options(mldr32 PRIVATE -pthread)
	target_link_options(mldr32 PRIVATE -pthread)
	target_link_libraries(mldr32 PRIVATE -lrt -ldl mldr32_dserver_rpc)

	install(TARGETS mldr32 DESTINATION libexec/darling/usr/libexec/darling)
endif()
