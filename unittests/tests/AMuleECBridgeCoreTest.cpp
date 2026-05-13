#include "../../src/AMuleECBridgeCore.h"

#include <cstdlib>
#include <iostream>
#include <string>

namespace {

void Require(bool condition, const char* message)
{
	if (!condition) {
		std::cerr << message << std::endl;
		std::exit(1);
	}
}

void RequireContains(const std::string& text, const char* fragment)
{
	Require(text.find(fragment) != std::string::npos, fragment);
}

} // namespace

int main()
{
	const std::string json = AMuleECBridge::BuildCapabilitiesEnvelope();
	RequireContains(json, "\"ok\":true");
	RequireContains(json, "\"schema_version\":1");
	RequireContains(json, "\"client_name\":\"aMuleNativeBridge\"");
	RequireContains(json, "\"default_host\":\"127.0.0.1\"");
	RequireContains(json, "\"default_port\":4712");
	RequireContains(json, "\"capabilities\"");
	RequireContains(json, "\"ops\"");
	RequireContains(json, "\"status\"");

	const char* raw = AMuleECBridgeCopyCapabilitiesJson();
	Require(raw != NULL, "AMuleECBridgeCopyCapabilitiesJson returned null");
	const std::string cJson(raw);
	AMuleECBridgeFreeString(raw);
	RequireContains(cJson, "\"ok\":true");
	RequireContains(cJson, "\"capabilities\"");

	std::cout << json << std::endl;
	return 0;
}
