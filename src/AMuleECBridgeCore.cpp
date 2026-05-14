#include "AMuleECBridgeCore.h"

#ifndef VERSION
#define VERSION "GIT"
#endif

#include "AMuleECBridgeJson.h"

#include <cstdlib>
#include <cstring>
#include <iostream>
#include <sstream>

#define AMULE_EC_BRIDGE_CORE_EMBEDDED 1
#include "AMuleECBridge.cpp"

namespace MuleNotify
{
	void HandleNotification(const CMuleNotiferBase&) __attribute__((weak));
	void HandleNotificationAlways(const CMuleNotiferBase&) __attribute__((weak));
	void HandleNotification(const CMuleNotiferBase&) {}
	void HandleNotificationAlways(const CMuleNotiferBase&) {}
}

namespace {

const char* CopyJsonString(const std::string& json)
{
	char* copy = static_cast<char*>(std::malloc(json.size() + 1));
	if (copy == NULL) {
		return NULL;
	}
	std::memcpy(copy, json.c_str(), json.size() + 1);
	return copy;
}

std::string ErrorEnvelope(const std::string& message)
{
	return std::string("{\"ok\":false,\"error\":\"") + ::JsonEscape(message) + "\"}";
}

void AddArg(std::vector<std::string>& args, const char* key, const char* value)
{
	if (value == NULL) {
		return;
	}
	args.push_back(key);
	args.push_back(value);
}

void AddArg(std::vector<std::string>& args, const char* key, int value)
{
	std::ostringstream text;
	text << value;
	args.push_back(key);
	args.push_back(text.str());
}

const char* RunOperationJson(
	const char* operation,
	const char* host,
	int port,
	const char* password,
	const std::vector<std::string>& extraArgs
)
{
	Options options;
	options.op = operation ? operation : "";
	options.host = (host && *host) ? host : AMuleECBridge::DefaultHost();
	options.port = port > 0 ? port : AMuleECBridge::DefaultPort();
	options.password = password ? password : "";

	std::vector<std::string> argv;
	argv.push_back("amule-ec-bridge-core");
	argv.push_back("--op");
	argv.push_back(options.op);
	argv.push_back("--host");
	argv.push_back(options.host);
	argv.push_back("--port");
	{
		std::ostringstream portText;
		portText << options.port;
		argv.push_back(portText.str());
	}
	if (!options.password.empty() || options.op != "capabilities") {
		argv.push_back("--password");
		argv.push_back(options.password);
	}
	argv.insert(argv.end(), extraArgs.begin(), extraArgs.end());

	std::vector<char*> rawArgv;
	for (size_t i = 0; i < argv.size(); ++i) {
		rawArgv.push_back(const_cast<char*>(argv[i].c_str()));
	}

	std::string error;
	if (!ParseArgs(static_cast<int>(rawArgv.size()), rawArgv.data(), options, error)) {
		return CopyJsonString(ErrorEnvelope(error));
	}

	std::ostringstream captured;
	std::streambuf* old = std::cout.rdbuf(captured.rdbuf());
	const int code = ExecuteBridgeOperation(options, error);
	std::cout.rdbuf(old);

	if (code != 0) {
		return CopyJsonString(ErrorEnvelope(error.empty() ? "Unknown error" : error));
	}

	std::string json = captured.str();
	while (!json.empty() && (json[json.size() - 1] == '\n' || json[json.size() - 1] == '\r')) {
		json.erase(json.size() - 1);
	}
	return CopyJsonString(json);
}

} // namespace

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
		"kad-update-from-url",
		"prefs-connection-get",
		"prefs-connection-set"
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
	return CopyJsonString(json);
}

const char* AMuleECBridgeCopyOperationJson(
	const char* operation,
	const char* host,
	int port,
	const char* password,
	int argc,
	const char* const* argv
)
{
	std::vector<std::string> extraArgs;
	for (int i = 0; i < argc; ++i) {
		extraArgs.push_back(argv && argv[i] ? argv[i] : "");
	}
	return RunOperationJson(operation, host, port, password, extraArgs);
}

const char* AMuleECBridgeCopyConnectJson(const char* host, int port, const char* password)
{
	return RunOperationJson("connect", host, port, password, std::vector<std::string>());
}

const char* AMuleECBridgeCopyStatusJson(const char* host, int port, const char* password)
{
	return RunOperationJson("status", host, port, password, std::vector<std::string>());
}

const char* AMuleECBridgeCopyDownloadsJson(const char* host, int port, const char* password)
{
	return RunOperationJson("downloads", host, port, password, std::vector<std::string>());
}

const char* AMuleECBridgeCopySearchJson(const char* host, int port, const char* password, const char* scope, const char* query, int polls, int pollIntervalMs)
{
	std::vector<std::string> args;
	AddArg(args, "--scope", scope ? scope : "kad");
	AddArg(args, "--query", query ? query : "");
	AddArg(args, "--polls", polls);
	AddArg(args, "--poll-interval-ms", pollIntervalMs);
	return RunOperationJson("search", host, port, password, args);
}

const char* AMuleECBridgeCopyAddLinkJson(const char* host, int port, const char* password, const char* link)
{
	std::vector<std::string> args;
	AddArg(args, "--link", link ? link : "");
	return RunOperationJson("add-link", host, port, password, args);
}

const char* AMuleECBridgeCopyPauseJson(const char* host, int port, const char* password, const char* hash)
{
	std::vector<std::string> args;
	AddArg(args, "--hash", hash ? hash : "");
	return RunOperationJson("pause", host, port, password, args);
}

const char* AMuleECBridgeCopyResumeJson(const char* host, int port, const char* password, const char* hash)
{
	std::vector<std::string> args;
	AddArg(args, "--hash", hash ? hash : "");
	return RunOperationJson("resume", host, port, password, args);
}

const char* AMuleECBridgeCopyServerConnectJson(const char* host, int port, const char* password, const char* serverIP, int serverPort)
{
	std::vector<std::string> args;
	if (serverIP && *serverIP) {
		AddArg(args, "--server-ip", serverIP);
		AddArg(args, "--server-port", serverPort);
	}
	return RunOperationJson("server-connect", host, port, password, args);
}

void AMuleECBridgeFreeString(const char* value)
{
	std::free(const_cast<char*>(value));
}
