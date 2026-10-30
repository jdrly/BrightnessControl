// Private IOKit calls for Apple silicon's display AV service, exported by
// IOKit.framework but not in its headers. Same declarations as m1ddc
// (github.com/waydabber/m1ddc).
#pragma once

#include <CoreFoundation/CoreFoundation.h>
#include <IOKit/IOKitLib.h>

typedef CFTypeRef IOAVServiceRef;

extern IOAVServiceRef _Nullable IOAVServiceCreateWithService(CFAllocatorRef _Nullable allocator, io_service_t service) CF_RETURNS_RETAINED;
extern IOReturn IOAVServiceReadI2C(IOAVServiceRef _Nonnull service, uint32_t chipAddress, uint32_t offset, void * _Nonnull outputBuffer, uint32_t outputBufferSize);
extern IOReturn IOAVServiceWriteI2C(IOAVServiceRef _Nonnull service, uint32_t chipAddress, uint32_t dataAddress, void * _Nonnull inputBuffer, uint32_t inputBufferSize);
