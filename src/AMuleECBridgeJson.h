#ifndef AMULE_EC_BRIDGE_JSON_H
#define AMULE_EC_BRIDGE_JSON_H

#include <cstddef>
#include <cstdio>
#include <iostream>
#include <sstream>
#include <string>
#include <vector>

inline std::string JsonEscape(const std::string& in)
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

inline void PrintJsonError(const std::string& message)
{
    std::cout << "{\"ok\":false,\"error\":\"" << JsonEscape(message) << "\"}" << std::endl;
}

inline void PrintJsonMessage(const std::string& message)
{
    std::cout << "{\"ok\":true,\"message\":\"" << JsonEscape(message) << "\"}" << std::endl;
}

inline std::string BuildCapabilitiesJson(
    const std::string& bridgeVersion,
    const std::string& clientName,
    const std::string& defaultHost,
    int defaultPort,
    const std::vector<std::string>& ops
)
{
    std::ostringstream out;
    out << "{\"ok\":true,\"schema_version\":1,\"capabilities\":{";
    out << "\"bridge_version\":\"" << JsonEscape(bridgeVersion) << "\",";
    out << "\"client_name\":\"" << JsonEscape(clientName) << "\",";
    out << "\"default_host\":\"" << JsonEscape(defaultHost) << "\",";
    out << "\"default_port\":" << defaultPort << ",";
    out << "\"ops\":[";
    for (size_t i = 0; i < ops.size(); ++i) {
        if (i != 0) {
            out << ",";
        }
        out << "\"" << JsonEscape(ops[i]) << "\"";
    }
    out << "]}}";
    return out.str();
}

#endif
