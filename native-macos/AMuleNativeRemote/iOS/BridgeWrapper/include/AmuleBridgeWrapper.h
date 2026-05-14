#ifndef AMULE_BRIDGE_WRAPPER_H
#define AMULE_BRIDGE_WRAPPER_H

#ifdef __cplusplus
extern "C" {
#endif

const char* AMuleBridgeWrapperCopyCapabilitiesJSON(void);
const char* AMuleBridgeWrapperCopyConnectJSON(const char* host, int port, const char* password);
const char* AMuleBridgeWrapperCopyDisconnectJSON(const char* host, int port, const char* password);
const char* AMuleBridgeWrapperCopyStatusJSON(const char* host, int port, const char* password);
const char* AMuleBridgeWrapperCopyDownloadsJSON(const char* host, int port, const char* password);
const char* AMuleBridgeWrapperCopySearchJSON(
    const char* host,
    int port,
    const char* password,
    const char* scope,
    const char* query,
    int polls,
    int pollIntervalMs
);
const char* AMuleBridgeWrapperCopySearchStopJSON(const char* host, int port, const char* password);
const char* AMuleBridgeWrapperCopyDownloadJSON(const char* host, int port, const char* password, const char* hash);
const char* AMuleBridgeWrapperCopyAddLinkJSON(const char* host, int port, const char* password, const char* link);
const char* AMuleBridgeWrapperCopyPauseJSON(const char* host, int port, const char* password, const char* hash);
const char* AMuleBridgeWrapperCopyResumeJSON(const char* host, int port, const char* password, const char* hash);
const char* AMuleBridgeWrapperCopyCancelJSON(const char* host, int port, const char* password, const char* hash);
const char* AMuleBridgeWrapperCopyServerConnectJSON(
    const char* host,
    int port,
    const char* password,
    const char* serverIP,
    int serverPort
);
const char* AMuleBridgeWrapperCopySourcesJSON(const char* host, int port, const char* password, const char* hash);
const char* AMuleBridgeWrapperCopyPrefsConnectionGetJSON(const char* host, int port, const char* password);
const char* AMuleBridgeWrapperCopyPrefsConnectionSetJSON(const char* host, int port, const char* password, int maxDownload, int maxUpload);

void AMuleBridgeWrapperFreeString(const char* value);

#ifdef __cplusplus
}
#endif

#endif
