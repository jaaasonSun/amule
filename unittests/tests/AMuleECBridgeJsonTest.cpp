#include <muleunit/test.h>

#include "AMuleECBridgeJson.h"

#include <iostream>
#include <sstream>
#include <string>
#include <vector>

using namespace muleunit;

DECLARE_SIMPLE(AMuleECBridgeJson)

TEST(AMuleECBridgeJson, JsonEscapeEscapesSpecialAndControlCharacters)
{
	std::string input("\"\\\b\f\n\r\t");
	input.push_back(static_cast<char>(1));
	input += "plain";

	ASSERT_EQUALS("\\\"\\\\\\b\\f\\n\\r\\t\\u0001plain", JsonEscape(input));
}

TEST(AMuleECBridgeJson, PrintJsonErrorWritesEscapedEnvelope)
{
	std::ostringstream captured;
	std::streambuf* original = std::cout.rdbuf(captured.rdbuf());

	PrintJsonError("bad \"line\"\n");

	std::cout.rdbuf(original);
	ASSERT_EQUALS("{\"ok\":false,\"error\":\"bad \\\"line\\\"\\n\"}\n", captured.str());
}

TEST(AMuleECBridgeJson, PrintJsonMessageWritesEscapedEnvelope)
{
	std::ostringstream captured;
	std::streambuf* original = std::cout.rdbuf(captured.rdbuf());

	PrintJsonMessage("ok\tline");

	std::cout.rdbuf(original);
	ASSERT_EQUALS("{\"ok\":true,\"message\":\"ok\\tline\"}\n", captured.str());
}

TEST(AMuleECBridgeJson, BuildCapabilitiesJsonIncludesSchemaAndStatusOp)
{
	std::vector<std::string> ops;
	ops.push_back("status");
	ops.push_back("downloads");

	const std::string json = BuildCapabilitiesJson("1.2.3", "Bridge", "127.0.0.1", 4712, ops);

	ASSERT_TRUE(json.find("\"schema_version\":1") != std::string::npos);
	ASSERT_TRUE(json.find("\"ops\":[\"status\",\"downloads\"]") != std::string::npos);
	ASSERT_TRUE(json.find("\"capabilities\":{") != std::string::npos);
}
