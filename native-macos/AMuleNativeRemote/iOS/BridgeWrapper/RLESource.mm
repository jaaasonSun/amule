#include <TargetConditionals.h>
#if TARGET_OS_IPHONE
#define wxUSE_GUI 0
#include "../../../../src/RLE.cpp"
#endif
