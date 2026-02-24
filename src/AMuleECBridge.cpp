// This file is part of the aMule Project.

#include "config.h"

#include "libs/ec/cpp/RemoteConnect.h"
#include "libs/ec/cpp/ECSpecialTags.h"
#include "libs/common/MD5Sum.h"
#include "Constants.h"
#include "GuiEvents.h"
#include "NetworkFunctions.h"
#include "RLE.h"
#include <protocol/ed2k/Constants.h>
#include <protocol/ed2k/ClientSoftware.h>

#include <wx/init.h>
#include <wx/intl.h>
#include <wx/string.h>

#include <chrono>
#include <algorithm>
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
	std::string link;
	std::string name;
	std::string priority = "normal";
	std::string serverAddress;
	std::string serverName;
	std::string serverURL;
	std::string kadURL;
	std::string serverIP;
	int serverPort = 0;
	int polls = 10;
	int pollIntervalMs = 900;
	std::vector<uint32_t> ecids;
};

struct DownloadEntry {
	struct AlternativeName {
		std::string name;
		int count = 0;
	};

	uint32_t ecid = 0;
	std::string hash;
	std::string name;
	uint64_t size = 0;
	uint64_t done = 0;
	uint64_t transferred = 0;
	double progress = 0.0;
	int sourceCurrent = 0;
	int sourceTotal = 0;
	int sourceTransferring = 0;
	int sourceA4AF = 0;
	std::string status;
	uint32_t speed = 0;
	int priority = 0;
	int category = 0;
	uint32_t statusCode = 0;
	bool isCompleted = false;
	std::string partMetName;
	uint64_t lastSeenComplete = 0;
	uint64_t lastReceived = 0;
	uint32_t activeSeconds = 0;
	uint32_t availableParts = 0;
	bool shared = false;
	std::vector<AlternativeName> alternativeNames;
	std::vector<uint32_t> progressColors;
};

struct SourceEntry {
	uint32_t clientID = 0;
	uint32_t requestFileID = 0;
	std::string clientName;
	std::string userIP;
	uint16_t userPort = 0;
	std::string serverName;
	std::string serverIP;
	uint16_t serverPort = 0;
	std::string software;
	std::string softwareVersion;
	uint32_t downloadState = 0;
	std::string downloadStateText;
	uint32_t sourceFrom = 0;
	std::string sourceFromText;
	double downSpeedKBps = 0.0;
	uint32_t availableParts = 0;
	uint32_t remoteQueueRank = 0;
	uint32_t obfuscationStatus = 0;
	bool extendedProtocol = false;
	std::string remoteFilename;
};

struct SearchEntry {
	uint32_t id = 0;
	std::string hash;
	std::string name;
	uint64_t size = 0;
	uint32_t sources = 0;
	uint32_t completeSources = 0;
	uint32_t statusCode = 0;
	std::string status;
	uint32_t parentID = 0;
	bool alreadyHave = false;
};

struct ServerEntry {
	uint32_t id = 0;
	std::string name;
	std::string description;
	std::string version;
	std::string address;
	std::string ip;
	uint16_t port = 0;
	uint32_t users = 0;
	uint32_t maxUsers = 0;
	uint32_t files = 0;
	uint32_t ping = 0;
	uint32_t failed = 0;
	uint32_t priority = 0;
	bool isStatic = false;
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

uint32_t PackColor(int r, int g, int b)
{
	return ((static_cast<uint32_t>(b) & 0xff) << 16)
		| ((static_cast<uint32_t>(g) & 0xff) << 8)
		| (static_cast<uint32_t>(r) & 0xff);
}

struct ColoredRange {
	uint64_t start = 0;
	uint64_t end = 0;
	uint32_t color = 0;
};

std::vector<uint32_t> BuildProgressSegments(const CEC_PartFile_Tag& tag)
{
	static const uint32_t kSegmentCount = 64;
	const uint32_t kDownloadedColor = PackColor(104, 104, 104);
	const uint32_t kRequestedColor = PackColor(255, 208, 0);
	std::vector<uint32_t> colorLine(kSegmentCount, kDownloadedColor);

	const uint64_t fileSize = tag.SizeFull();
	if (fileSize == 0) {
		return colorLine;
	}

	PartFileEncoderData encoder;
	ArrayOfUInts64 gaps;
	ArrayOfUInts16 partInfo;
	ArrayOfUInts64 reqs;

	const CECTag* gapTag = tag.GetTagByName(EC_TAG_PARTFILE_GAP_STATUS);
	const CECTag* partTag = tag.GetTagByName(EC_TAG_PARTFILE_PART_STATUS);
	const CECTag* reqTag = tag.GetTagByName(EC_TAG_PARTFILE_REQ_STATUS);

	if (gapTag) {
		encoder.DecodeGaps(gapTag, gaps);
	}
	if (partTag) {
		encoder.DecodeParts(partTag, partInfo);
	}
	if (reqTag) {
		encoder.DecodeReqs(reqTag, reqs);
	}

	std::vector<ColoredRange> gapRanges;
	const size_t gapPairs = gaps.size() / 2;
	for (size_t gapIndex = 0; gapIndex < gapPairs; ++gapIndex) {
		const uint64_t gapStart = gaps[2 * gapIndex];
		const uint64_t gapEnd = gaps[2 * gapIndex + 1];
		if (gapEnd <= gapStart) {
			continue;
		}

		const uint32_t startPart = static_cast<uint32_t>(gapStart / PARTSIZE);
		const uint32_t endPart = static_cast<uint32_t>((gapEnd / PARTSIZE) + 1);
		for (uint32_t part = startPart; part < endPart; ++part) {
			uint32_t color = PackColor(255, 0, 0);
			if (part < partInfo.size() && partInfo[part] > 0) {
				int green = 210 - (22 * (static_cast<int>(partInfo[part]) - 1));
				if (green < 0) {
					green = 0;
				}
				color = PackColor(0, green, 255);
			}

			const uint64_t fillStart = (part == startPart) ? gapStart : (static_cast<uint64_t>(PARTSIZE) * part);
			const uint64_t fillEnd = (part == (endPart - 1)) ? gapEnd : (static_cast<uint64_t>(PARTSIZE) * (part + 1));
			if (fillEnd <= fillStart) {
				continue;
			}

			if (!gapRanges.empty() && gapRanges.back().end == fillStart && gapRanges.back().color == color) {
				gapRanges.back().end = fillEnd;
			} else {
				ColoredRange range;
				range.start = fillStart;
				range.end = fillEnd;
				range.color = color;
				gapRanges.push_back(range);
			}
		}
	}

	std::vector<ColoredRange> reqRanges;
	const size_t reqPairs = reqs.size() / 2;
	reqRanges.reserve(reqPairs);
	for (size_t reqIndex = 0; reqIndex < reqPairs; ++reqIndex) {
		const uint64_t reqStart = reqs[2 * reqIndex];
		const uint64_t reqEnd = reqs[2 * reqIndex + 1];
		if (reqEnd <= reqStart) {
			continue;
		}
		ColoredRange range;
		range.start = reqStart;
		range.end = reqEnd;
		range.color = kRequestedColor;
		reqRanges.push_back(range);
	}

	if (fileSize < kSegmentCount) {
		if (!reqRanges.empty()) {
			std::fill(colorLine.begin(), colorLine.end(), kRequestedColor);
		} else if (!gapRanges.empty()) {
			std::fill(colorLine.begin(), colorLine.end(), gapRanges.front().color);
		}
		return colorLine;
	}

	const uint64_t factor = fileSize / kSegmentCount;
	if (factor == 0) {
		return colorLine;
	}

	auto paintRanges = [&](const std::vector<ColoredRange>& ranges) {
		for (size_t rangeIndex = 0; rangeIndex < ranges.size(); ++rangeIndex) {
			uint32_t start = static_cast<uint32_t>(ranges[rangeIndex].start / factor);
			uint32_t end = static_cast<uint32_t>(ranges[rangeIndex].end / factor);

			if (start >= kSegmentCount) {
				continue;
			}
			if (end > kSegmentCount) {
				end = kSegmentCount;
			}
			if (end <= start) {
				end = std::min(kSegmentCount, start + 1);
			}
			for (uint32_t pos = start; pos < end; ++pos) {
				colorLine[pos] = ranges[rangeIndex].color;
			}
		}
	};

	paintRanges(gapRanges);
	paintRanges(reqRanges);
	return colorLine;
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
		} else if (arg == "--link") {
			if (!needValue(arg, options.link)) return false;
		} else if (arg == "--name") {
			if (!needValue(arg, options.name)) return false;
		} else if (arg == "--priority") {
			if (!needValue(arg, options.priority)) return false;
		} else if (arg == "--server-address") {
			if (!needValue(arg, options.serverAddress)) return false;
		} else if (arg == "--server-name") {
			if (!needValue(arg, options.serverName)) return false;
		} else if (arg == "--server-url") {
			if (!needValue(arg, options.serverURL)) return false;
		} else if (arg == "--kad-url") {
			if (!needValue(arg, options.kadURL)) return false;
		} else if (arg == "--server-ip") {
			if (!needValue(arg, options.serverIP)) return false;
		} else if (arg == "--server-port") {
			std::string serverPort;
			if (!needValue(arg, serverPort)) return false;
			options.serverPort = std::atoi(serverPort.c_str());
		} else if (arg == "--polls") {
			std::string polls;
			if (!needValue(arg, polls)) return false;
			options.polls = std::atoi(polls.c_str());
		} else if (arg == "--poll-interval-ms") {
			std::string ms;
			if (!needValue(arg, ms)) return false;
			options.pollIntervalMs = std::atoi(ms.c_str());
		} else if (arg == "--ecid") {
			std::string ecidStr;
			if (!needValue(arg, ecidStr)) return false;
			const int ecid = std::atoi(ecidStr.c_str());
			if (ecid <= 0) {
				error = "Invalid --ecid value";
				return false;
			}
			options.ecids.push_back(static_cast<uint32_t>(ecid));
		} else if (arg == "--help") {
			error =
				"Usage: amule-ec-bridge --host <ip> --port <port> --password <plain_or_md5> --op <status|downloads|sources|search|search-stop|download|add-link|rename|connect|disconnect|pause|resume|cancel|priority|clear-completed|servers|server-connect|server-disconnect|server-add|server-remove|server-update-from-url|kad-update-from-url> [op args]";
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

bool ParseServerEndpoint(const Options& options, uint32& ip, uint16& port, std::string& error)
{
	std::string ipText = options.serverIP;
	int portValue = options.serverPort;

	if (ipText.empty()) {
		if (options.serverAddress.empty()) {
			error = "Missing --server-ip/--server-port or --server-address";
			return false;
		}
		const std::string::size_type split = options.serverAddress.rfind(':');
		if (split == std::string::npos || split == 0 || split + 1 >= options.serverAddress.size()) {
			error = "Invalid --server-address format. Use a.b.c.d:port";
			return false;
		}
		ipText = options.serverAddress.substr(0, split);
		portValue = std::atoi(options.serverAddress.substr(split + 1).c_str());
	}

	if (portValue <= 0 || portValue > 65535) {
		error = "Invalid server port";
		return false;
	}

	if (!StringIPtoUint32(wxString::FromUTF8(ipText.c_str()), ip) || ip == 0) {
		error = "Invalid server IP address";
		return false;
	}

	port = static_cast<uint16>(portValue);
	return true;
}

bool TagUInt(const CECTag& parent, ec_tagname_t name, uint32& out)
{
	const CECTag* tag = parent.GetTagByName(name);
	if (!tag || !tag->IsInt()) {
		return false;
	}
	out = static_cast<uint32>(tag->GetInt());
	return true;
}

bool TagUInt16(const CECTag& parent, ec_tagname_t name, uint16& out)
{
	uint32 value = 0;
	if (!TagUInt(parent, name, value) || value > 65535) {
		return false;
	}
	out = static_cast<uint16>(value);
	return true;
}

bool TagString(const CECTag& parent, ec_tagname_t name, std::string& out)
{
	const CECTag* tag = parent.GetTagByName(name);
	if (!tag || !tag->IsString()) {
		return false;
	}
	out = ToUtf8(tag->GetStringData());
	return true;
}

bool TagDoubleValue(const CECTag& parent, ec_tagname_t name, double& out)
{
	const CECTag* tag = parent.GetTagByName(name);
	if (!tag) {
		return false;
	}
	out = tag->GetDoubleData();
	return true;
}

std::string SoftwareCodeToText(uint32_t code)
{
	switch (code) {
		case SO_OLDEMULE:
		case SO_EMULE:
			return "eMule";
		case SO_CDONKEY:
			return "cDonkey";
		case SO_LXMULE:
			return "(l/x)Mule";
		case SO_AMULE:
			return "aMule";
		case SO_SHAREAZA:
		case SO_NEW_SHAREAZA:
		case SO_NEW2_SHAREAZA:
			return "Shareaza";
		case SO_EMULEPLUS:
			return "eMule+";
		case SO_HYDRANODE:
			return "HydraNode";
		case SO_MLDONKEY:
		case SO_NEW_MLDONKEY:
		case SO_NEW2_MLDONKEY:
			return "MLDonkey";
		case SO_LPHANT:
			return "lphant";
		case SO_EDONKEYHYBRID:
			return "eDonkeyHybrid";
		case SO_EDONKEY:
			return "eDonkey";
		case SO_COMPAT_UNK:
			return "eMule Compatible";
		case SO_UNKNOWN:
		default:
			return "Unknown";
	}
}

std::string DownloadStateToText(uint32_t state, bool queueFull)
{
	switch (state) {
		case DS_CONNECTING: return "Connecting";
		case DS_CONNECTED: return "Asking";
		case DS_WAITCALLBACK: return "Connecting via server";
		case DS_ONQUEUE: return queueFull ? "Queue Full" : "On Queue";
		case DS_DOWNLOADING: return "Downloading";
		case DS_REQHASHSET: return "Receiving hashset";
		case DS_NONEEDEDPARTS: return "No needed parts";
		case DS_LOWTOLOWIP: return "Cannot connect LowID to LowID";
		case DS_TOOMANYCONNS: return "Too many connections";
		case DS_WAITCALLBACKKAD: return "Connecting via Kad";
		case DS_TOOMANYCONNSKAD: return "Too many Kad connections";
		case DS_BANNED: return "Banned";
		case DS_ERROR: return "Connection Error";
		case DS_REMOTEQUEUEFULL: return "Remote Queue Full";
		case DS_NONE:
		default:
			return "Unknown";
	}
}

std::string SourceFromToText(uint32_t sourceFrom)
{
	switch (sourceFrom) {
		case SF_LOCAL_SERVER: return "Local Server";
		case SF_REMOTE_SERVER: return "Remote Server";
		case SF_KADEMLIA: return "Kad";
		case SF_SOURCE_EXCHANGE: return "Source Exchange";
		case SF_PASSIVE: return "Passive";
		case SF_LINK: return "Link";
		case SF_SOURCE_SEEDS: return "Source Seeds";
		case SF_SEARCH_RESULT: return "Search Result";
		case SF_NONE:
		default:
			return "Unknown";
	}
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
	// Use incremental update feed so completed downloads kept by core are included,
	// matching what amulegui/amule-remote-gui consume.
	CECPacket req(EC_OP_GET_UPDATE, EC_DETAIL_INC_UPDATE);
	std::unique_ptr<const CECPacket> reply = SendRecvChecked(conn, req, error);
	if (!reply) {
		return false;
	}

	std::vector<DownloadEntry> entries;
	for (CECPacket::const_iterator it = reply->begin(); it != reply->end(); ++it) {
		const CECTag& top = *it;
		// Skip grouped update branches.
		if (top.GetTagName() == EC_TAG_CLIENT || top.GetTagName() == EC_TAG_SERVER || top.GetTagName() == EC_TAG_FRIEND) {
			continue;
		}
		// Keep only partfile-like entries (shared known files don't carry partfile status).
		if (!top.GetTagByName(EC_TAG_PARTFILE_STATUS) || !top.GetTagByName(EC_TAG_PARTFILE_HASH)) {
			continue;
		}
		const CEC_PartFile_Tag* tag = static_cast<const CEC_PartFile_Tag*>(&top);
		DownloadEntry e;
		e.ecid = tag->ID();
		e.hash = ToUtf8(tag->FileHashString());
		e.name = ToUtf8(tag->FileName());
		e.size = tag->SizeFull();
		e.done = tag->SizeDone();
		e.transferred = tag->SizeXfer();
		e.progress = e.size ? (100.0 * static_cast<double>(e.done) / static_cast<double>(e.size)) : 0.0;
		e.sourceCurrent = static_cast<int>(tag->SourceCount()) - static_cast<int>(tag->SourceNotCurrCount());
		e.sourceTotal = static_cast<int>(tag->SourceCount());
		e.sourceTransferring = static_cast<int>(tag->SourceXferCount());
		e.sourceA4AF = static_cast<int>(tag->SourceCountA4AF());
		e.statusCode = static_cast<uint32_t>(tag->FileStatus());
		e.isCompleted = (e.statusCode == PS_COMPLETE);
		e.status = ToUtf8(tag->GetFileStatusString());
		e.speed = tag->Speed();
		e.priority = tag->DownPrio();
		e.category = tag->FileCat();
		e.partMetName = ToUtf8(tag->PartMetName());
		e.lastSeenComplete = static_cast<uint64_t>(tag->LastSeenComplete());
		e.lastReceived = static_cast<uint64_t>(tag->LastDateChanged());
		e.activeSeconds = tag->DownloadActiveTime();
		e.availableParts = tag->AvailablePartCount();
		e.shared = tag->Shared();
		e.progressColors = BuildProgressSegments(*tag);

		const CECTag* srcNamesTag = tag->GetTagByName(EC_TAG_PARTFILE_SOURCE_NAMES);
		if (srcNamesTag) {
			for (CECTag::const_iterator srcIt = srcNamesTag->begin(); srcIt != srcNamesTag->end(); ++srcIt) {
				const CECTag* countTag = srcIt->GetTagByName(EC_TAG_PARTFILE_SOURCE_NAMES_COUNTS);
				const CECTag* nameTag = srcIt->GetTagByName(EC_TAG_PARTFILE_SOURCE_NAMES);
				if (!countTag || !countTag->IsInt() || !nameTag || !nameTag->IsString()) {
					continue;
				}
				const int count = static_cast<int>(countTag->GetInt());
				const std::string altName = ToUtf8(nameTag->GetStringData());
				if (count <= 0 || altName.empty()) {
					continue;
				}
				if (altName == e.name) {
					continue;
				}
				DownloadEntry::AlternativeName alt;
				alt.name = altName;
				alt.count = count;
				e.alternativeNames.push_back(alt);
			}

			std::sort(
				e.alternativeNames.begin(),
				e.alternativeNames.end(),
				[](const DownloadEntry::AlternativeName& a, const DownloadEntry::AlternativeName& b) {
					if (a.count != b.count) {
						return a.count > b.count;
					}
					return a.name < b.name;
				});

			const size_t kMaxAlternativeNames = 12;
			if (e.alternativeNames.size() > kMaxAlternativeNames) {
				e.alternativeNames.resize(kMaxAlternativeNames);
			}
		}
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
			<< "\"ecid\":" << e.ecid << ","
			<< "\"hash\":\"" << JsonEscape(e.hash) << "\"," 
			<< "\"name\":\"" << JsonEscape(e.name) << "\"," 
			<< "\"size\":" << e.size << ","
			<< "\"done\":" << e.done << ","
			<< "\"transferred\":" << e.transferred << ","
			<< "\"progress\":" << e.progress << ","
			<< "\"sources_current\":" << e.sourceCurrent << ","
			<< "\"sources_total\":" << e.sourceTotal << ","
			<< "\"sources_transferring\":" << e.sourceTransferring << ","
			<< "\"sources_a4af\":" << e.sourceA4AF << ","
			<< "\"status_code\":" << e.statusCode << ","
			<< "\"is_completed\":" << (e.isCompleted ? "true" : "false") << ","
			<< "\"status\":\"" << JsonEscape(e.status) << "\"," 
			<< "\"speed\":" << e.speed << ","
			<< "\"priority\":" << e.priority << ","
			<< "\"category\":" << e.category << ","
			<< "\"part_met\":\"" << JsonEscape(e.partMetName) << "\"," 
			<< "\"last_seen_complete\":" << e.lastSeenComplete << ","
			<< "\"last_received\":" << e.lastReceived << ","
			<< "\"active_seconds\":" << e.activeSeconds << ","
			<< "\"available_parts\":" << e.availableParts << ","
			<< "\"shared\":" << (e.shared ? "true" : "false") << ","
			<< "\"alternative_names\":[";
		for (size_t ai = 0; ai < e.alternativeNames.size(); ++ai) {
			const DownloadEntry::AlternativeName& alt = e.alternativeNames[ai];
			if (ai != 0) {
				std::cout << ",";
			}
			std::cout
				<< "{"
				<< "\"name\":\"" << JsonEscape(alt.name) << "\","
				<< "\"count\":" << alt.count
				<< "}";
		}
		std::cout
			<< "],"
			<< "\"progress_colors\":[";
		for (size_t ci = 0; ci < e.progressColors.size(); ++ci) {
			if (ci != 0) {
				std::cout << ",";
			}
			std::cout << e.progressColors[ci];
		}
		std::cout
			<< "]"
			<< "}";
	}
	std::cout << "]}" << std::endl;
	return true;
}

bool HandleSources(CRemoteConnect& conn, const Options& options, std::string& error)
{
	if (options.hash.empty()) {
		error = "Missing --hash";
		return false;
	}

	CMD4Hash hash;
	if (!DecodeHash(options.hash, hash)) {
		error = "Invalid --hash value";
		return false;
	}

	uint32_t partFileID = 0;
	{
		CECPacket queueReq(EC_OP_GET_DLOAD_QUEUE, EC_DETAIL_CMD);
		std::unique_ptr<const CECPacket> queueReply = SendRecvChecked(conn, queueReq, error);
		if (!queueReply) {
			return false;
		}

		for (CECPacket::const_iterator it = queueReply->begin(); it != queueReply->end(); ++it) {
			const CEC_PartFile_Tag* fileTag = static_cast<const CEC_PartFile_Tag*>(&*it);
			if (fileTag->FileHash() == hash) {
				partFileID = fileTag->ID();
				break;
			}
		}
	}

	if (partFileID == 0) {
		error = "File not found in download queue";
		return false;
	}

	CECPacket updateReq(EC_OP_GET_UPDATE, EC_DETAIL_INC_UPDATE);
	std::unique_ptr<const CECPacket> updateReply = SendRecvChecked(conn, updateReq, error);
	if (!updateReply) {
		return false;
	}

	std::vector<SourceEntry> entries;
	auto processClientTag = [&](const CECTag& clientTag) {
		uint32_t requestFileID = 0;
		if (!TagUInt(clientTag, EC_TAG_CLIENT_REQUEST_FILE, requestFileID) || requestFileID != partFileID) {
			return;
		}

		SourceEntry entry;
		entry.clientID = static_cast<uint32_t>(clientTag.GetInt());
		entry.requestFileID = requestFileID;
		TagString(clientTag, EC_TAG_CLIENT_NAME, entry.clientName);
		TagString(clientTag, EC_TAG_CLIENT_REMOTE_FILENAME, entry.remoteFilename);
		TagString(clientTag, EC_TAG_CLIENT_SERVER_NAME, entry.serverName);
		TagString(clientTag, EC_TAG_CLIENT_SOFT_VER_STR, entry.softwareVersion);
		TagUInt16(clientTag, EC_TAG_CLIENT_USER_PORT, entry.userPort);
		TagUInt16(clientTag, EC_TAG_CLIENT_SERVER_PORT, entry.serverPort);
		TagUInt(clientTag, EC_TAG_CLIENT_AVAILABLE_PARTS, entry.availableParts);
		TagUInt(clientTag, EC_TAG_CLIENT_REMOTE_QUEUE_RANK, entry.remoteQueueRank);
		TagUInt(clientTag, EC_TAG_CLIENT_OBFUSCATION_STATUS, entry.obfuscationStatus);

		uint32_t userIP = 0;
		if (TagUInt(clientTag, EC_TAG_CLIENT_USER_IP, userIP) && userIP != 0) {
			entry.userIP = ToUtf8(Uint32toStringIP(userIP));
		}

		uint32_t serverIP = 0;
		if (TagUInt(clientTag, EC_TAG_CLIENT_SERVER_IP, serverIP) && serverIP != 0) {
			entry.serverIP = ToUtf8(Uint32toStringIP(serverIP));
		}

		uint32_t softwareCode = SO_UNKNOWN;
		if (TagUInt(clientTag, EC_TAG_CLIENT_SOFTWARE, softwareCode)) {
			entry.software = SoftwareCodeToText(softwareCode);
		} else {
			entry.software = "Unknown";
		}

		uint32_t sourceFrom = SF_NONE;
		if (TagUInt(clientTag, EC_TAG_CLIENT_FROM, sourceFrom)) {
			entry.sourceFrom = sourceFrom;
		}
		entry.sourceFromText = SourceFromToText(entry.sourceFrom);

		uint32_t downloadState = DS_NONE;
		if (TagUInt(clientTag, EC_TAG_CLIENT_DOWNLOAD_STATE, downloadState)) {
			entry.downloadState = downloadState;
		}
		const bool queueFull = entry.remoteQueueRank == 0xffff || entry.downloadState == DS_REMOTEQUEUEFULL;
		entry.downloadStateText = DownloadStateToText(entry.downloadState, queueFull);

		double downSpeedKBps = 0.0;
		if (TagDoubleValue(clientTag, EC_TAG_CLIENT_DOWN_SPEED, downSpeedKBps)) {
			entry.downSpeedKBps = downSpeedKBps;
		}

		uint32_t extProtocol = 0;
		if (TagUInt(clientTag, EC_TAG_CLIENT_EXT_PROTOCOL, extProtocol)) {
			entry.extendedProtocol = extProtocol != 0;
		}

		entries.push_back(entry);
	};

	for (CECPacket::const_iterator it = updateReply->begin(); it != updateReply->end(); ++it) {
		const CECTag& topTag = *it;
		if (topTag.GetTagName() != EC_TAG_CLIENT) {
			continue;
		}

		if (topTag.HasChildTags()) {
			for (CECTag::const_iterator clientIt = topTag.begin(); clientIt != topTag.end(); ++clientIt) {
				if (clientIt->GetTagName() != EC_TAG_CLIENT) {
					continue;
				}
				processClientTag(*clientIt);
			}
		} else {
			processClientTag(topTag);
		}
	}

	std::sort(
		entries.begin(),
		entries.end(),
		[](const SourceEntry& a, const SourceEntry& b) {
			if (a.downloadState != b.downloadState) {
				return a.downloadState < b.downloadState;
			}
			if (a.downSpeedKBps != b.downSpeedKBps) {
				return a.downSpeedKBps > b.downSpeedKBps;
			}
			if (a.clientName != b.clientName) {
				return a.clientName < b.clientName;
			}
			return a.clientID < b.clientID;
		});

	std::cout << "{\"ok\":true,\"sources\":[";
	for (size_t i = 0; i < entries.size(); ++i) {
		const SourceEntry& e = entries[i];
		if (i != 0) {
			std::cout << ",";
		}
		std::cout
			<< "{"
			<< "\"client_id\":" << e.clientID << ","
			<< "\"request_file_id\":" << e.requestFileID << ","
			<< "\"client_name\":\"" << JsonEscape(e.clientName) << "\","
			<< "\"user_ip\":\"" << JsonEscape(e.userIP) << "\","
			<< "\"user_port\":" << e.userPort << ","
			<< "\"server_name\":\"" << JsonEscape(e.serverName) << "\","
			<< "\"server_ip\":\"" << JsonEscape(e.serverIP) << "\","
			<< "\"server_port\":" << e.serverPort << ","
			<< "\"software\":\"" << JsonEscape(e.software) << "\","
			<< "\"software_version\":\"" << JsonEscape(e.softwareVersion) << "\","
			<< "\"download_state\":" << e.downloadState << ","
			<< "\"download_state_text\":\"" << JsonEscape(e.downloadStateText) << "\","
			<< "\"source_from\":" << e.sourceFrom << ","
			<< "\"source_from_text\":\"" << JsonEscape(e.sourceFromText) << "\","
			<< "\"down_speed_kbps\":" << e.downSpeedKBps << ","
			<< "\"available_parts\":" << e.availableParts << ","
			<< "\"remote_queue_rank\":" << e.remoteQueueRank << ","
			<< "\"obfuscation_status\":" << e.obfuscationStatus << ","
			<< "\"extended_protocol\":" << (e.extendedProtocol ? "true" : "false") << ","
			<< "\"remote_filename\":\"" << JsonEscape(e.remoteFilename) << "\""
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
	std::map<uint32_t, size_t> indexByID;

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
			entry.id = tag->ID();
			entry.hash = ToUtf8(tag->FileHashString());
			entry.name = ToUtf8(tag->FileName());
			entry.size = tag->SizeFull();
			entry.sources = tag->SourceCount();
			entry.completeSources = tag->CompleteSourceCount();
			entry.statusCode = tag->DownloadStatus();
			switch (entry.statusCode) {
				case 1: entry.status = "Downloaded"; break;
				case 2: entry.status = "Queued"; break;
				case 3: entry.status = "Canceled"; break;
				case 4: entry.status = "Queued (Canceled)"; break;
				default: entry.status = "New"; break;
			}
			entry.parentID = tag->ParentID();
			entry.alreadyHave = tag->AlreadyHave();

			std::map<uint32_t, size_t>::iterator pos = indexByID.find(entry.id);
			if (pos == indexByID.end()) {
				indexByID[entry.id] = ordered.size();
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
				<< "\"id\":" << e.id << ","
				<< "\"hash\":\"" << JsonEscape(e.hash) << "\"," 
				<< "\"name\":\"" << JsonEscape(e.name) << "\"," 
				<< "\"size\":" << e.size << ","
				<< "\"sources\":" << e.sources << ","
				<< "\"complete_sources\":" << e.completeSources << ","
				<< "\"status_code\":" << e.statusCode << ","
				<< "\"status\":\"" << JsonEscape(e.status) << "\","
				<< "\"parent_id\":" << e.parentID << ","
				<< "\"already_have\":" << (e.alreadyHave ? "true" : "false")
				<< "}";
		}
	std::cout << "]}" << std::endl;
	return true;
}

bool HandleSearchStop(CRemoteConnect& conn, std::string& error)
{
	CECPacket req(EC_OP_SEARCH_STOP);
	std::unique_ptr<const CECPacket> reply = SendRecvChecked(conn, req, error);
	if (!reply) {
		return false;
	}
	PrintJsonMessage("Search stop requested");
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

bool HandleAddLink(CRemoteConnect& conn, const Options& options, std::string& error)
{
	if (options.link.empty()) {
		error = "Missing --link value";
		return false;
	}

	wxString link = wxString::FromUTF8(options.link.c_str());
	if (link.StartsWith(wxT("ed2k://"))) {
		if (link.Find(wxT("|h=")) > -1 && link.Find(wxT("|/|h=")) == -1) {
			link.Replace(wxT("|h="), wxT("|/|h="));
		}
		if (link.StartsWith(wxT("ed2k://%7C"))) {
			link.Replace(wxT("%7C"), wxT("|"));
		}
	}

	CECPacket req(EC_OP_ADD_LINK);
	req.AddTag(CECTag(EC_TAG_STRING, link));
	std::unique_ptr<const CECPacket> reply = SendRecvChecked(conn, req, error);
	if (!reply) {
		return false;
	}
	PrintJsonMessage("Link add request accepted");
	return true;
}

bool HandleRename(CRemoteConnect& conn, const Options& options, std::string& error)
{
	CMD4Hash hash;
	if (!DecodeHash(options.hash, hash)) {
		error = "Invalid --hash value";
		return false;
	}
	if (options.name.empty()) {
		error = "Missing --name";
		return false;
	}

	CECPacket req(EC_OP_RENAME_FILE);
	req.AddTag(CECTag(EC_TAG_KNOWNFILE, hash));
	req.AddTag(CECTag(EC_TAG_PARTFILE_NAME, wxString::FromUTF8(options.name.c_str())));
	std::unique_ptr<const CECPacket> reply = SendRecvChecked(conn, req, error);
	if (!reply) {
		return false;
	}
	PrintJsonMessage("Rename requested");
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

bool HandleClearCompleted(CRemoteConnect& conn, const Options& options, std::string& error)
{
	std::vector<uint32_t> toClear = options.ecids;
	if (toClear.empty()) {
		CECPacket queueReq(EC_OP_GET_DLOAD_QUEUE, EC_DETAIL_CMD);
		std::unique_ptr<const CECPacket> queueReply = SendRecvChecked(conn, queueReq, error);
		if (!queueReply) {
			return false;
		}

		for (CECPacket::const_iterator it = queueReply->begin(); it != queueReply->end(); ++it) {
			const CEC_PartFile_Tag* tag = static_cast<const CEC_PartFile_Tag*>(&*it);
			if (tag->FileStatus() == PS_COMPLETE) {
				toClear.push_back(tag->ID());
			}
		}
	}

	if (toClear.empty()) {
		PrintJsonMessage("No completed downloads to clear");
		return true;
	}

	CECPacket req(EC_OP_CLEAR_COMPLETED);
	for (std::vector<uint32_t>::const_iterator it = toClear.begin(); it != toClear.end(); ++it) {
		req.AddTag(CECTag(EC_TAG_ECID, *it));
	}

	std::unique_ptr<const CECPacket> reply = SendRecvChecked(conn, req, error);
	if (!reply) {
		return false;
	}
	PrintJsonMessage("Completed downloads cleared");
	return true;
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

bool HandleServers(CRemoteConnect& conn, std::string& error)
{
	CECPacket req(EC_OP_GET_SERVER_LIST, EC_DETAIL_FULL);
	std::unique_ptr<const CECPacket> reply = SendRecvChecked(conn, req, error);
	if (!reply) {
		return false;
	}

	std::vector<ServerEntry> entries;
	for (CECPacket::const_iterator it = reply->begin(); it != reply->end(); ++it) {
		const CECTag& tag = *it;
		ServerEntry e;
		e.id = static_cast<uint32_t>(entries.size() + 1);

		TagString(tag, EC_TAG_SERVER_NAME, e.name);
		TagString(tag, EC_TAG_SERVER_DESC, e.description);
		TagString(tag, EC_TAG_SERVER_VERSION, e.version);
		TagString(tag, EC_TAG_SERVER_ADDRESS, e.address);
		TagUInt(tag, EC_TAG_SERVER_USERS, e.users);
		TagUInt(tag, EC_TAG_SERVER_USERS_MAX, e.maxUsers);
		TagUInt(tag, EC_TAG_SERVER_FILES, e.files);
		TagUInt(tag, EC_TAG_SERVER_PING, e.ping);
		TagUInt(tag, EC_TAG_SERVER_FAILED, e.failed);
		TagUInt(tag, EC_TAG_SERVER_PRIO, e.priority);

		uint32 isStatic = 0;
		if (TagUInt(tag, EC_TAG_SERVER_STATIC, isStatic)) {
			e.isStatic = isStatic != 0;
		}

		// Server list entries usually encode endpoint data as IPv4 in the parent tag.
		EC_IPv4_t endpoint = tag.GetIPv4Data();
		if (endpoint.IP() != 0) {
			e.ip = ToUtf8(Uint32toStringIP(endpoint.IP()));
			e.port = endpoint.m_port;
		} else {
			uint32 ipRaw = 0;
			if (TagUInt(tag, EC_TAG_SERVER_IP, ipRaw) && ipRaw != 0) {
				e.ip = ToUtf8(Uint32toStringIP(ipRaw));
			}
			TagUInt16(tag, EC_TAG_SERVER_PORT, e.port);
		}

		if (e.address.empty()) {
			if (!e.ip.empty() && e.port != 0) {
				std::ostringstream portText;
				portText << e.port;
				e.address = e.ip + ":" + portText.str();
			} else if (!e.ip.empty()) {
				e.address = e.ip;
			}
		}

		entries.push_back(e);
	}

	std::cout << "{\"ok\":true,\"servers\":[";
	for (size_t i = 0; i < entries.size(); ++i) {
		const ServerEntry& e = entries[i];
		if (i != 0) {
			std::cout << ",";
		}
		std::cout
			<< "{"
			<< "\"id\":" << e.id << ","
			<< "\"name\":\"" << JsonEscape(e.name) << "\"," 
			<< "\"description\":\"" << JsonEscape(e.description) << "\"," 
			<< "\"version\":\"" << JsonEscape(e.version) << "\"," 
			<< "\"address\":\"" << JsonEscape(e.address) << "\"," 
			<< "\"ip\":\"" << JsonEscape(e.ip) << "\"," 
			<< "\"port\":" << e.port << ","
			<< "\"users\":" << e.users << ","
			<< "\"max_users\":" << e.maxUsers << ","
			<< "\"files\":" << e.files << ","
			<< "\"ping\":" << e.ping << ","
			<< "\"failed\":" << e.failed << ","
			<< "\"priority\":" << e.priority << ","
			<< "\"is_static\":" << (e.isStatic ? "true" : "false")
			<< "}";
	}
	std::cout << "]}" << std::endl;
	return true;
}

bool HandleServerConnect(CRemoteConnect& conn, const Options& options, std::string& error)
{
	CECPacket req(EC_OP_SERVER_CONNECT);
	if (!options.serverIP.empty() || !options.serverAddress.empty()) {
		uint32 ip = 0;
		uint16 port = 0;
		if (!ParseServerEndpoint(options, ip, port, error)) {
			return false;
		}
		req.AddTag(CECTag(EC_TAG_SERVER, EC_IPv4_t(ip, port)));
	}

	std::unique_ptr<const CECPacket> reply = SendRecvChecked(conn, req, error);
	if (!reply) {
		return false;
	}
	PrintJsonMessage("Server connect requested");
	return true;
}

bool HandleServerDisconnect(CRemoteConnect& conn, std::string& error)
{
	CECPacket req(EC_OP_SERVER_DISCONNECT);
	std::unique_ptr<const CECPacket> reply = SendRecvChecked(conn, req, error);
	if (!reply) {
		return false;
	}
	PrintJsonMessage("Server disconnect requested");
	return true;
}

bool HandleServerAdd(CRemoteConnect& conn, const Options& options, std::string& error)
{
	if (options.serverAddress.empty()) {
		error = "Missing --server-address";
		return false;
	}

	CECPacket req(EC_OP_SERVER_ADD);
	req.AddTag(CECTag(EC_TAG_SERVER_ADDRESS, wxString::FromUTF8(options.serverAddress.c_str())));
	if (!options.serverName.empty()) {
		req.AddTag(CECTag(EC_TAG_SERVER_NAME, wxString::FromUTF8(options.serverName.c_str())));
	}

	std::unique_ptr<const CECPacket> reply = SendRecvChecked(conn, req, error);
	if (!reply) {
		return false;
	}
	PrintJsonMessage("Server add requested");
	return true;
}

bool HandleServerRemove(CRemoteConnect& conn, const Options& options, std::string& error)
{
	uint32 ip = 0;
	uint16 port = 0;
	if (!ParseServerEndpoint(options, ip, port, error)) {
		return false;
	}

	conn.RemoveServer(ip, port);
	PrintJsonMessage("Server remove requested");
	return true;
}

bool HandleServerUpdateFromURL(CRemoteConnect& conn, const Options& options, std::string& error)
{
	if (options.serverURL.empty()) {
		error = "Missing --server-url";
		return false;
	}

	CECPacket req(EC_OP_SERVER_UPDATE_FROM_URL);
	req.AddTag(CECTag(EC_TAG_SERVERS_UPDATE_URL, wxString::FromUTF8(options.serverURL.c_str())));

	std::unique_ptr<const CECPacket> reply = SendRecvChecked(conn, req, error);
	if (!reply) {
		return false;
	}

	PrintJsonMessage("Server list update requested");
	return true;
}

bool HandleKadUpdateFromURL(CRemoteConnect& conn, const Options& options, std::string& error)
{
	if (options.kadURL.empty()) {
		error = "Missing --kad-url";
		return false;
	}

	CECPacket req(EC_OP_KAD_UPDATE_FROM_URL);
	req.AddTag(CECTag(EC_TAG_KADEMLIA_UPDATE_URL, wxString::FromUTF8(options.kadURL.c_str())));

	std::unique_ptr<const CECPacket> reply = SendRecvChecked(conn, req, error);
	if (!reply) {
		return false;
	}

	PrintJsonMessage("Kad nodes update requested");
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
	} else if (options.op == "sources") {
		ok = HandleSources(conn, options, error);
	} else if (options.op == "servers") {
		ok = HandleServers(conn, error);
	} else if (options.op == "search") {
		ok = HandleSearch(conn, options, error);
	} else if (options.op == "search-stop") {
		ok = HandleSearchStop(conn, error);
	} else if (options.op == "download") {
		ok = HandleDownloadHash(conn, options, error);
	} else if (options.op == "add-link") {
		ok = HandleAddLink(conn, options, error);
	} else if (options.op == "rename") {
		ok = HandleRename(conn, options, error);
	} else if (options.op == "connect" || options.op == "disconnect") {
		ok = HandleConnectDisconnect(conn, options, error);
	} else if (options.op == "pause" || options.op == "resume" || options.op == "cancel" || options.op == "priority") {
		ok = HandlePartFileAction(conn, options, error);
	} else if (options.op == "clear-completed") {
		ok = HandleClearCompleted(conn, options, error);
	} else if (options.op == "server-connect") {
		ok = HandleServerConnect(conn, options, error);
	} else if (options.op == "server-disconnect") {
		ok = HandleServerDisconnect(conn, error);
	} else if (options.op == "server-add") {
		ok = HandleServerAdd(conn, options, error);
	} else if (options.op == "server-remove") {
		ok = HandleServerRemove(conn, options, error);
	} else if (options.op == "server-update-from-url") {
		ok = HandleServerUpdateFromURL(conn, options, error);
	} else if (options.op == "kad-update-from-url") {
		ok = HandleKadUpdateFromURL(conn, options, error);
	} else {
		error = "Unsupported --op value";
	}

	if (!ok) {
		PrintJsonError(error.empty() ? "Unknown error" : error);
		return 1;
	}

	return 0;
}
