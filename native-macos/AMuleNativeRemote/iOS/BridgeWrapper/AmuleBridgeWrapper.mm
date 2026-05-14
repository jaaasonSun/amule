#include "AmuleBridgeWrapper.h"

#include <string>

#include "../../../../src/AMuleECBridgeCore.h"

const char* AMuleBridgeWrapperCopyCapabilitiesJSON(void)
{
    return AMuleECBridgeCopyCapabilitiesJson();
}

const char* AMuleBridgeWrapperCopyConnectJSON(const char* host, int port, const char* password)
{
    return AMuleECBridgeCopyConnectJson(host, port, password);
}

const char* AMuleBridgeWrapperCopyDisconnectJSON(const char* host, int port, const char* password)
{
    return AMuleECBridgeCopyOperationJson("disconnect", host, port, password, 0, nullptr);
}

const char* AMuleBridgeWrapperCopyStatusJSON(const char* host, int port, const char* password)
{
    return AMuleECBridgeCopyStatusJson(host, port, password);
}

const char* AMuleBridgeWrapperCopyDownloadsJSON(const char* host, int port, const char* password)
{
    return AMuleECBridgeCopyDownloadsJson(host, port, password);
}

const char* AMuleBridgeWrapperCopySearchJSON(
    const char* host,
    int port,
    const char* password,
    const char* scope,
    const char* query,
    int polls,
    int pollIntervalMs
)
{
    return AMuleECBridgeCopySearchJson(host, port, password, scope, query, polls, pollIntervalMs);
}

const char* AMuleBridgeWrapperCopySearchStopJSON(const char* host, int port, const char* password)
{
    return AMuleECBridgeCopyOperationJson("search-stop", host, port, password, 0, nullptr);
}

const char* AMuleBridgeWrapperCopyDownloadJSON(const char* host, int port, const char* password, const char* hash)
{
    const char* const args[] = { "--hash", hash ? hash : "" };
    return AMuleECBridgeCopyOperationJson("download", host, port, password, 2, args);
}

const char* AMuleBridgeWrapperCopyAddLinkJSON(const char* host, int port, const char* password, const char* link)
{
    return AMuleECBridgeCopyAddLinkJson(host, port, password, link);
}

const char* AMuleBridgeWrapperCopyPauseJSON(const char* host, int port, const char* password, const char* hash)
{
    return AMuleECBridgeCopyPauseJson(host, port, password, hash);
}

const char* AMuleBridgeWrapperCopyResumeJSON(const char* host, int port, const char* password, const char* hash)
{
    return AMuleECBridgeCopyResumeJson(host, port, password, hash);
}

const char* AMuleBridgeWrapperCopyCancelJSON(const char* host, int port, const char* password, const char* hash)
{
    const char* const args[] = { "--hash", hash ? hash : "" };
    return AMuleECBridgeCopyOperationJson("cancel", host, port, password, 2, args);
}

const char* AMuleBridgeWrapperCopyServersJSON(const char* host, int port, const char* password)
{
    return AMuleECBridgeCopyOperationJson("servers", host, port, password, 0, nullptr);
}

const char* AMuleBridgeWrapperCopyServerConnectJSON(
    const char* host,
    int port,
    const char* password,
    const char* serverIP,
    int serverPort
)
{
    return AMuleECBridgeCopyServerConnectJson(host, port, password, serverIP, serverPort);
}

const char* AMuleBridgeWrapperCopyServerDisconnectJSON(const char* host, int port, const char* password)
{
    return AMuleECBridgeCopyOperationJson("server-disconnect", host, port, password, 0, nullptr);
}

const char* AMuleBridgeWrapperCopyServerAddJSON(const char* host, int port, const char* password, const char* address, const char* name)
{
    const char* const argsWithName[] = { "--server-address", address ? address : "", "--server-name", name ? name : "" };
    const char* const argsWithoutName[] = { "--server-address", address ? address : "" };
    if (name && name[0] != '\0') {
        return AMuleECBridgeCopyOperationJson("server-add", host, port, password, 4, argsWithName);
    }
    return AMuleECBridgeCopyOperationJson("server-add", host, port, password, 2, argsWithoutName);
}

const char* AMuleBridgeWrapperCopyServerRemoveJSON(const char* host, int port, const char* password, const char* serverIP, int serverPort)
{
    char serverPortBuf[16];
    snprintf(serverPortBuf, sizeof(serverPortBuf), "%d", serverPort);
    const char* const args[] = { "--server-ip", serverIP ? serverIP : "", "--server-port", serverPortBuf };
    return AMuleECBridgeCopyOperationJson("server-remove", host, port, password, 4, args);
}

const char* AMuleBridgeWrapperCopyServerUpdateFromURLJSON(const char* host, int port, const char* password, const char* url)
{
    const char* const args[] = { "--server-url", url ? url : "" };
    return AMuleECBridgeCopyOperationJson("server-update-from-url", host, port, password, 2, args);
}

const char* AMuleBridgeWrapperCopySourcesJSON(const char* host, int port, const char* password, const char* hash)
{
    const char* const args[] = { "--hash", hash ? hash : "" };
    return AMuleECBridgeCopyOperationJson("sources", host, port, password, 2, args);
}

const char* AMuleBridgeWrapperCopyPrefsConnectionGetJSON(const char* host, int port, const char* password)
{
    return AMuleECBridgeCopyOperationJson("prefs-connection-get", host, port, password, 0, nullptr);
}

const char* AMuleBridgeWrapperCopyPrefsConnectionSetJSON(const char* host, int port, const char* password, int maxDownload, int maxUpload)
{
    char maxDLBuf[16];
    char maxULBuf[16];
    snprintf(maxDLBuf, sizeof(maxDLBuf), "%d", maxDownload);
    snprintf(maxULBuf, sizeof(maxULBuf), "%d", maxUpload);
    const char* const args[] = { "--max-dl", maxDLBuf, "--max-ul", maxULBuf };
    return AMuleECBridgeCopyOperationJson("prefs-connection-set", host, port, password, 4, args);
}

void AMuleBridgeWrapperFreeString(const char* value)
{
    AMuleECBridgeFreeString(value);
}
