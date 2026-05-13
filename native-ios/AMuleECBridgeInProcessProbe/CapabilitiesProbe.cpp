#include "../../src/AMuleECBridgeCore.h"

#include <iostream>

int main()
{
	const char* json = AMuleECBridgeCopyCapabilitiesJson();
	if (json == NULL) {
		std::cerr << "AMuleECBridgeCopyCapabilitiesJson returned null" << std::endl;
		return 1;
	}

	std::cout << json << std::endl;
	AMuleECBridgeFreeString(json);
	return 0;
}
