#include <TargetConditionals.h>
#if TARGET_OS_IPHONE
#define wxUSE_GUI 0
#include "../../../../src/kademlia/utils/UInt128.cpp"
#endif
