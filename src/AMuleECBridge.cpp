// This file is part of the aMule Project.

#include "config.h"

#include "libs/ec/cpp/RemoteConnect.h"
#include "libs/ec/cpp/ECSpecialTags.h"
#include "libs/common/MD5Sum.h"
#include "Constants.h"
#include "GuiEvents.h"

#include <wx/init.h>
#include <wx/intl.h>
#include <wx/string.h>

#include <chrono>
#include <cstdio>
#include <cstdint>
#include <cstdlib>
#include <iostream>
#include <map>
#include <memory>
#include <sstream>
#include <string>
#include <thread>
#include <vector>

namespace {

struct Options {
	std::string host = "127.0.0.1";
	int port = 4712;
	std::string password;
	std::string op;
	std::string scope = "kad";
	std::string query;
	std::string hash;
	std::string priority = "normal";
	int polls = 10;
	int pollIntervalMs = 900;
};

struct DownloadEntry {
	std::string hash;
	std::string name;
	double progress = 0.0;
	int sourceCurrent = 0;
	int sourceTotal = 0;
	std::string status;
	uint32_t speed = 0;
	int priority = 0;
};

struct SearchEntry {
	std::string hash;
	std::string name;
	uint64_t size = 0;
	uint32_t sources = 0;
	bool alreadyHave = false;
};

std::string ToUtf8(const wxString& value)
{
	const wxCharBuffer buffer = value.utf8_str();
	return buffer ? std::string(buffer.data()) : std::string();
}

std::string JsonEscape(const std::string& in)
{
	std::ostringstream out;
	for (std::string::const_iterator it = in.begin(); it != in.end(); ++it) {
		unsigned char c = static_cast<unsigned char>(*it);
		switch (c) {
			case '"': out << "\\\""; break;
			case '\\': out << "\\\\"; break;
			case '\b': out << "\\b"; break;
			case '\f': out << "\\f"; break;
			case '\n': out << "\\n"; break;
			case '\r': out << "\\r"; break;
			case '\t': out << "\\t"; break;
			default:
				if (c < 0x20) {
					char tmp[7];
					snprintf(tmp, sizeof(tmp), "\\u%04X", c);
					out << tmp;
				} else {
					out << *it;
				}
		}
	}
	return out.str();
}

void PrintJsonError(const std::string& message)
{
	std::cout << "{\"ok\":false,\"error\":\"" << JsonEscape(message) << "\"}" << std::endl;
}

void PrintJsonMessage(const std::string& message)
{
	std::cout << "{\"ok\":true,\"message\":\"" << JsonEscape(message) << "\"}" << std::endl;
}

bool ParseArgs(int argc, char** argv, Options& options, std::string& error)
{
	for (int i = 1; i < argc; ++i) {
		const std::string arg(argv[i]);
		auto needValue = [&](const std::string& key, std::string& target) -> bool {
			if (i + 1 >= argc) {
				error = "Missing value for " + key;
				return false;
			}
			target = argv[++i];
			return true;
		};

		if (arg == "--host") {
			if (!needValue(arg, options.host)) return false;
		} else if (arg == "--port") {
			std::string portStr;
			if (!needValue(arg, portStr)) return false;
			options.port = std::atoi(portStr.c_str());
		} else if (arg == "--password") {
			if (!needValue(arg, options.password)) return false;
		} else if (arg == "--op") {
			if (!needValue(arg, options.op)) return false;
		} else if (arg == "--scope") {
			if (!needValue(arg, options.scope)) return false;
		} else if (arg == "--query") {
			if (!needValue(arg, options.query)) return false;
		} else if (arg == "--hash") {
			if (!needValue(arg, options.hash)) return false;
		} else if (arg == "--priority") {
			if (!needValue(arg, options.priority)) return false;
		} else if (arg == "--polls") {
			std::string polls;
			if (!needValue(arg, polls)) return false;
			options.polls = std::atoi(polls.c_str());
		} else if (arg == "--poll-interval-ms") {
			std::string ms;
			if (!needValue(arg, ms)) return false;
			options.pollIntervalMs = std::atoi(ms.c_str());
		} else if (arg == "--help") {
			error =
				"Usage: amule-ec-bridge --host <ip> --port <port> --password <plain_or_md5> --op <status|downloads|search|download|connect|disconnect|pause|resume|cancel|priority> [op args]";
			return false;
		} else {
			error = "Unknown argument: " + arg;
			return false;
		}
	}

	if (options.op.empty()) {
		error = "Missing --op";
		return false;
	}
	if (options.password.empty()) {
		error = "Missing --password";
		return false;
	}
	return true;
}

std::unique_ptr<const CECPacket> SendRecvChecked(CRemoteConnect& conn, CECPacket& req, std::string& error)
{
	const CECPacket* raw = conn.SendRecvPacket(&req);
	if (!raw) {
		error = "No reply received from core";
		return std::unique_ptr<const CECPacket>();
	}
	std::unique_ptr<const CECPacket> reply(raw);
	if (reply->GetOpCode() == EC_OP_FAILED) {
		const CECTag* tag = reply->GetFirstTagSafe();
		if (tag && tag->IsString()) {
			error = ToUtf8(wxGetTranslation(tag->GetStringData()));
		} else {
			error = "Request failed";
		}
		return std::unique_ptr<const CECPacket>();
	}
	return reply;
}

bool NormalizePassword(const std::string& input, wxString& md5Password)
{
	wxString pass = wxString::FromUTF8(input.c_str());
	CMD4Hash hash;
	if (hash.Decode(pass) && !hash.IsEmpty()) {
		md5Password = pass.Lower();
		return true;
	}
	md5Password = MD5Sum(pass).GetHash().Lower();
	return true;
}

int PriorityFromText(const std::string& text)
{
	if (text == "low") return PR_LOW;
	if (text == "normal") return PR_NORMAL;
	if (text == "high") return PR_HIGH;
	if (text == "auto") return PR_AUTO;
	return -1;
}

bool DecodeHash(const std::string& text, CMD4Hash& out)
{
	wxString value = wxString::FromUTF8(text.c_str());
	return out.Decode(value) && !out.IsEmpty();
}

std::string BuildED2KStatus(const CEC_ConnState_Tag* state)
{
	if (!state) return "Unknown";
	if (state->IsConnectedED2K()) {
		const CECTag* server = state->GetTagByName(EC_TAG_SERVER);
		const CECTag* serverName = server ? server->GetTagByName(EC_TAG_SERVER_NAME) : NULL;
		std::ostringstream text;
		if (server && serverName) {
			text << "Connected to "
				 << ToUtf8(serverName->GetStringData())
				 << " "
				 << ToUtf8(server->GetIPv4Data().StringIP())
				 << " "
				 << (state->HasLowID() ? "LowID" : "HighID");
		} else {
			text << "Connected";
		}
		return text.str();
	}
	if (state->IsConnectingED2K()) {
		return "Connecting";
	}
	return "Not connected";
}

std::string BuildKadStatus(const CEC_ConnState_Tag* state)
{
	if (!state) return "Unknown";
	if (!state->IsKadRunning()) {
		return "Not running";
	}
	if (state->IsConnectedKademlia()) {
		return state->IsKadFirewalled() ? "Connected (firewalled)" : "Connected (ok)";
	}
	return "Not connected";
}

bool HandleStatus(CRemoteConnect& conn, std::string& error)
{
	CECPacket req(EC_OP_STAT_REQ, EC_DETAIL_CMD);
	std::unique_ptr<const CECPacket> reply = SendRecvChecked(conn, req, error);
	if (!reply) {
		return false;
	}

	const CEC_ConnState_Tag* state = static_cast<const CEC_ConnState_Tag*>(reply->GetTagByName(EC_TAG_CONNSTATE));
	const CECTag* dl = reply->GetTagByName(EC_TAG_STATS_DL_SPEED);
	const CECTag* ul = reply->GetTagByName(EC_TAG_STATS_UL_SPEED);
	const CECTag* q = reply->GetTagByName(EC_TAG_STATS_UL_QUEUE_LEN);
	const CECTag* src = reply->GetTagByName(EC_TAG_STATS_TOTAL_SRC_COUNT);

	std::cout
		<< "{\"ok\":true,\"status\":{"
		<< "\"connected\":" << (state && state->IsConnected() ? "true" : "false") << ","
		<< "\"ed2k\":\"" << JsonEscape(BuildED2KStatus(state)) << "\"," 
		<< "\"kad\":\"" << JsonEscape(BuildKadStatus(state)) << "\"," 
		<< "\"download_speed\":" << (dl ? dl->GetInt() : 0) << ","
		<< "\"upload_speed\":" << (ul ? ul->GetInt() : 0) << ","
		<< "\"queue\":" << (q ? q->GetInt() : 0) << ","
		<< "\"sources\":" << (src ? src->GetInt() : 0)
		<< "}}" << std::endl;

	return true;
}

bool HandleDownloads(CRemoteConnect& conn, std::string& error)
{
	CECPacket req(EC_OP_GET_DLOAD_QUEUE, EC_DETAIL_FULL);
	std::unique_ptr<const CECPacket> reply = SendRecvChecked(conn, req, error);
	if (!reply) {
		return false;
	}

	std::vector<DownloadEntry> entries;
	for (CECPacket::const_iterator it = reply->begin(); it != reply->end(); ++it) {
		const CEC_PartFile_Tag* tag = static_cast<const CEC_PartFile_Tag*>(&*it);
		DownloadEntry e;
		e.hash = ToUtf8(tag->FileHashString());
		e.name = ToUtf8(tag->FileName());
		const uint64_t size = tag->SizeFull();
		const uint64_t done = tag->SizeDone();
		e.progress = size ? (100.0 * static_cast<double>(done) / static_cast<double>(size)) : 0.0;
		e.sourceCurrent = static_cast<int>(tag->SourceCount()) - static_cast<int>(tag->SourceNotCurrCount());
		e.sourceTotal = static_cast<int>(tag->SourceCount());
		e.status = ToUtf8(tag->GetFileStatusString());
		e.speed = tag->Speed();
		e.priority = tag->DownPrio();
		entries.push_back(e);
	}

	std::cout << "{\"ok\":true,\"downloads\":[";
	for (size_t i = 0; i < entries.size(); ++i) {
		const DownloadEntry& e = entries[i];
		if (i != 0) {
			std::cout << ",";
		}
		std::cout
			<< "{"
			<< "\"hash\":\"" << JsonEscape(e.hash) << "\"," 
			<< "\"name\":\"" << JsonEscape(e.name) << "\"," 
			<< "\"progress\":" << e.progress << ","
			<< "\"sources_current\":" << e.sourceCurrent << ","
			<< "\"sources_total\":" << e.sourceTotal << ","
			<< "\"status\":\"" << JsonEscape(e.status) << "\"," 
			<< "\"speed\":" << e.speed << ","
			<< "\"priority\":" << e.priority
			<< "}";
	}
	std::cout << "]}" << std::endl;
	return true;
}

bool HandleSearch(CRemoteConnect& conn, const Options& options, std::string& error)
{
	if (options.query.empty()) {
		error = "Missing --query for search operation";
		return false;
	}

	EC_SEARCH_TYPE searchType = EC_SEARCH_KAD;
	if (options.scope == "global") {
		searchType = EC_SEARCH_GLOBAL;
	} else if (options.scope == "local") {
		searchType = EC_SEARCH_LOCAL;
	}

	CECPacket start(EC_OP_SEARCH_START);
	start.AddTag(CEC_Search_Tag(
		wxString::FromUTF8(options.query.c_str()),
		searchType,
		wxEmptyString,
		wxEmptyString,
		0,
		0,
		0));

	std::unique_ptr<const CECPacket> startReply = SendRecvChecked(conn, start, error);
	if (!startReply) {
		return false;
	}

	uint32_t progress = 0;
	std::vector<SearchEntry> ordered;
	std::map<std::string, size_t> indexByHash;

	const int polls = options.polls > 0 ? options.polls : 10;
	const int interval = options.pollIntervalMs > 0 ? options.pollIntervalMs : 900;

	for (int i = 0; i < polls; ++i) {
		std::this_thread::sleep_for(std::chrono::milliseconds(interval));

		CECPacket progressReq(EC_OP_SEARCH_PROGRESS);
		std::unique_ptr<const CECPacket> progressReply = SendRecvChecked(conn, progressReq, error);
		if (progressReply) {
			const CECTag* t = progressReply->GetTagByName(EC_TAG_SEARCH_STATUS);
			if (t) {
				progress = t->GetInt();
			}
		}

		CECPacket resultsReq(EC_OP_SEARCH_RESULTS, EC_DETAIL_FULL);
		std::unique_ptr<const CECPacket> resultsReply = SendRecvChecked(conn, resultsReq, error);
		if (!resultsReply) {
			return false;
		}

		for (CECPacket::const_iterator it = resultsReply->begin(); it != resultsReply->end(); ++it) {
			const CEC_SearchFile_Tag* tag = static_cast<const CEC_SearchFile_Tag*>(&*it);
			SearchEntry entry;
			entry.hash = ToUtf8(tag->FileHashString());
			entry.name = ToUtf8(tag->FileName());
			entry.size = tag->SizeFull();
			entry.sources = tag->SourceCount();
			entry.alreadyHave = tag->AlreadyHave();

			std::map<std::string, size_t>::iterator pos = indexByHash.find(entry.hash);
			if (pos == indexByHash.end()) {
				indexByHash[entry.hash] = ordered.size();
				ordered.push_back(entry);
			} else {
				ordered[pos->second] = entry;
			}
		}

		if (progress >= 100 && !ordered.empty()) {
			break;
		}
	}

	std::cout << "{\"ok\":true,\"progress\":" << progress << ",\"results\":[";
	for (size_t i = 0; i < ordered.size(); ++i) {
		const SearchEntry& e = ordered[i];
		if (i != 0) {
			std::cout << ",";
		}
		std::cout
			<< "{"
			<< "\"id\":" << i << ","
			<< "\"hash\":\"" << JsonEscape(e.hash) << "\"," 
			<< "\"name\":\"" << JsonEscape(e.name) << "\"," 
			<< "\"size\":" << e.size << ","
			<< "\"sources\":" << e.sources << ","
			<< "\"already_have\":" << (e.alreadyHave ? "true" : "false")
			<< "}";
	}
	std::cout << "]}" << std::endl;
	return true;
}

bool HandleDownloadHash(CRemoteConnect& conn, const Options& options, std::string& error)
{
	CMD4Hash hash;
	if (!DecodeHash(options.hash, hash)) {
		error = "Invalid --hash value";
		return false;
	}

	CECPacket req(EC_OP_DOWNLOAD_SEARCH_RESULT);
	CECTag hashtag(EC_TAG_PARTFILE, hash);
	hashtag.AddTag(CECTag(EC_TAG_PARTFILE_CAT, static_cast<uint32>(0)));
	req.AddTag(hashtag);
	std::unique_ptr<const CECPacket> reply = SendRecvChecked(conn, req, error);
	if (!reply) {
		return false;
	}
	PrintJsonMessage("Download request accepted");
	return true;
}

bool HandlePartFileAction(CRemoteConnect& conn, const Options& options, std::string& error)
{
	CMD4Hash hash;
	if (!DecodeHash(options.hash, hash)) {
		error = "Invalid --hash value";
		return false;
	}

	const std::string& op = options.op;
	if (op == "pause" || op == "resume" || op == "cancel") {
		ec_opcode_t opcode = EC_OP_PARTFILE_PAUSE;
		if (op == "resume") opcode = EC_OP_PARTFILE_RESUME;
		if (op == "cancel") opcode = EC_OP_PARTFILE_DELETE;

		CECPacket req(opcode);
		req.AddTag(CECTag(EC_TAG_PARTFILE, hash));
		std::unique_ptr<const CECPacket> reply = SendRecvChecked(conn, req, error);
		if (!reply) {
			return false;
		}
		PrintJsonMessage("Action completed");
		return true;
	}

	if (op == "priority") {
		const int prio = PriorityFromText(options.priority);
		if (prio < 0) {
			error = "Invalid --priority value. Use low|normal|high|auto";
			return false;
		}

		CECPacket req(EC_OP_PARTFILE_PRIO_SET);
		CECTag fileTag(EC_TAG_PARTFILE, hash);
		fileTag.AddTag(CECTag(EC_TAG_PARTFILE_PRIO, static_cast<uint8>(prio)));
		req.AddTag(fileTag);
		std::unique_ptr<const CECPacket> reply = SendRecvChecked(conn, req, error);
		if (!reply) {
			return false;
		}
		PrintJsonMessage("Priority changed");
		return true;
	}

	error = "Unsupported action op";
	return false;
}

bool HandleConnectDisconnect(CRemoteConnect& conn, const Options& options, std::string& error)
{
	const bool connect = options.op == "connect";
	CECPacket req(connect ? EC_OP_CONNECT : EC_OP_DISCONNECT);
	std::unique_ptr<const CECPacket> reply = SendRecvChecked(conn, req, error);
	if (!reply) {
		return false;
	}
	PrintJsonMessage(connect ? "Connect requested" : "Disconnect requested");
	return true;
}

} // namespace

// Stubs needed for ASIO socket notifications in non-GUI tools.
namespace MuleNotify
{
	void HandleNotification(const CMuleNotiferBase&) {}
	void HandleNotificationAlways(const CMuleNotiferBase&) {}
}

int main(int argc, char** argv)
{
	wxInitializer initializer;
	if (!initializer.IsOk()) {
		PrintJsonError("Failed to initialize wxWidgets runtime");
		return 2;
	}

	Options options;
	std::string error;
	if (!ParseArgs(argc, argv, options, error)) {
		PrintJsonError(error);
		return 1;
	}

	wxString md5Password;
	if (!NormalizePassword(options.password, md5Password)) {
		PrintJsonError("Could not normalize password");
		return 1;
	}

	CRemoteConnect conn(NULL);
	conn.SetCapabilities(true, true, false);
	if (!conn.ConnectToCore(
		wxString::FromUTF8(options.host.c_str()),
		options.port,
		wxT("external"),
		md5Password,
		wxT("aMuleNativeBridge"),
		wxT(VERSION)
	)) {
		PrintJsonError(ToUtf8(conn.GetServerReply()));
		return 2;
	}

	bool ok = false;
	if (options.op == "status") {
		ok = HandleStatus(conn, error);
	} else if (options.op == "downloads") {
		ok = HandleDownloads(conn, error);
	} else if (options.op == "search") {
		ok = HandleSearch(conn, options, error);
	} else if (options.op == "download") {
		ok = HandleDownloadHash(conn, options, error);
	} else if (options.op == "connect" || options.op == "disconnect") {
		ok = HandleConnectDisconnect(conn, options, error);
	} else if (options.op == "pause" || options.op == "resume" || options.op == "cancel" || options.op == "priority") {
		ok = HandlePartFileAction(conn, options, error);
	} else {
		error = "Unsupported --op value";
	}

	if (!ok) {
		PrintJsonError(error.empty() ? "Unknown error" : error);
		return 1;
	}

	return 0;
}
