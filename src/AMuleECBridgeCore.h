#ifndef AMULE_EC_BRIDGE_CORE_H
#define AMULE_EC_BRIDGE_CORE_H

#ifdef __cplusplus
#include <string>
#include <vector>

namespace AMuleECBridge {

const char* BridgeVersion();
const char* ClientName();
const char* DefaultHost();
int DefaultPort();
const std::vector<std::string>& SupportedOps();
std::string BuildCapabilitiesEnvelope();

} // namespace AMuleECBridge

extern "C" {
#endif

const char* AMuleECBridgeCopyCapabilitiesJson(void);
const char* AMuleECBridgeCopyOperationJson(
	const char* operation,
	const char* host,
	int port,
	const char* password,
	int argc,
	const char* const* argv
);
const char* AMuleECBridgeCopyConnectJson(const char* host, int port, const char* password);
const char* AMuleECBridgeCopyStatusJson(const char* host, int port, const char* password);
const char* AMuleECBridgeCopyDownloadsJson(const char* host, int port, const char* password);
const char* AMuleECBridgeCopySearchJson(const char* host, int port, const char* password, const char* scope, const char* query, int polls, int pollIntervalMs);
const char* AMuleECBridgeCopyAddLinkJson(const char* host, int port, const char* password, const char* link);
const char* AMuleECBridgeCopyPauseJson(const char* host, int port, const char* password, const char* hash);
const char* AMuleECBridgeCopyResumeJson(const char* host, int port, const char* password, const char* hash);
const char* AMuleECBridgeCopyServerConnectJson(const char* host, int port, const char* password, const char* serverIP, int serverPort);
void AMuleECBridgeFreeString(const char* value);

#ifdef __cplusplus
}
#endif

#endif
