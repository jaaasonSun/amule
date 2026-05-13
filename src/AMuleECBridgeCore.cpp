#include "AMuleECBridgeCore.h"

#ifndef VERSION
#define VERSION "GIT"
#endif

#include "AMuleECBridgeJson.h"

#include <cstdlib>
#include <cstring>

namespace AMuleECBridge {

const char* BridgeVersion()
{
	return VERSION;
}

const char* ClientName()
{
	return "aMuleNativeBridge";
}

const char* DefaultHost()
{
	return "127.0.0.1";
}

int DefaultPort()
{
	return 4712;
}

const std::vector<std::string>& SupportedOps()
{
	static const std::vector<std::string> ops = {
		"capabilities",
		"status",
		"downloads",
		"sources",
		"search",
		"search-stop",
		"download",
		"add-link",
		"rename",
		"connect",
		"disconnect",
		"pause",
		"resume",
		"cancel",
		"priority",
		"clear-completed",
		"servers",
		"server-connect",
		"server-disconnect",
		"server-add",
		"server-remove",
		"server-update-from-url",
		"kad-update-from-url"
	};
	return ops;
}

std::string BuildCapabilitiesEnvelope()
{
	return BuildCapabilitiesJson(
		BridgeVersion(),
		ClientName(),
		DefaultHost(),
		DefaultPort(),
		SupportedOps()
	);
}

} // namespace AMuleECBridge

const char* AMuleECBridgeCopyCapabilitiesJson(void)
{
	const std::string json = AMuleECBridge::BuildCapabilitiesEnvelope();
	char* copy = static_cast<char*>(std::malloc(json.size() + 1));
	if (copy == NULL) {
		return NULL;
	}
	std::memcpy(copy, json.c_str(), json.size() + 1);
	return copy;
}

void AMuleECBridgeFreeString(const char* value)
{
	std::free(const_cast<char*>(value));
}
