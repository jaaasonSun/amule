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
void AMuleECBridgeFreeString(const char* value);

#ifdef __cplusplus
}
#endif

#endif
