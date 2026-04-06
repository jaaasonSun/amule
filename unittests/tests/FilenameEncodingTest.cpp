#include <muleunit/test.h>

#include <common/FilenameEncoding.h>
#include <common/StringFunctions.h>

using namespace muleunit;

DECLARE_SIMPLE(FilenameEncoding)

TEST(FilenameEncoding, LeavesAsciiUnchanged)
{
	ASSERT_EQUALS(wxT("plain-release.iso"), RepairFileNameEncoding(wxT("plain-release.iso")));
}

TEST(FilenameEncoding, LeavesValidUtf8NameUnchanged)
{
	ASSERT_EQUALS(wxT("Français.iso"), RepairFileNameEncoding(wxT("Français.iso")));
}

TEST(FilenameEncoding, RepairsClassicUtf8Mojibake)
{
	const wxString decoded = UnescapeHTML(wxT("Fran%C3%83%C2%A7ais.iso"));
	ASSERT_EQUALS(wxT("Français.iso"), RepairFileNameEncoding(decoded));
}

TEST(FilenameEncoding, ReportsWhenRepairWasApplied)
{
	bool repaired = false;
	ASSERT_EQUALS(wxT("Français.iso"), RepairFileNameEncoding(wxT("FranÃ§ais.iso"), &repaired));
	ASSERT_TRUE(repaired);
}

TEST(FilenameEncoding, RepairsCommonPunctuationMojibake)
{
	ASSERT_EQUALS(
		wxT("Rock – Café’s Best…live!.mp3"),
		RepairFileNameEncoding(wxT("Rock â€“ CafÃ©â€™s Bestâ€¦live!.mp3"))
	);
}

TEST(FilenameEncoding, LeavesAmbiguousLatin1NameUnchanged)
{
	ASSERT_EQUALS(wxT("Málaga.avi"), RepairFileNameEncoding(wxT("Málaga.avi")));
}

TEST(FilenameEncoding, LeavesLegitimateExtendedNameUnchanged)
{
	bool repaired = true;
	ASSERT_EQUALS(wxT("Ångström.txt"), RepairFileNameEncoding(wxT("Ångström.txt"), &repaired));
	ASSERT_FALSE(repaired);
}

TEST(FilenameEncoding, RepairsLongRepeatedMojibakeName)
{
	const wxString broken = wxT("FranÃ§ais-FranÃ§ais-FranÃ§ais-FranÃ§ais-FranÃ§ais.iso");
	const wxString repaired = wxT("Français-Français-Français-Français-Français.iso");
	ASSERT_EQUALS(repaired, RepairFileNameEncoding(broken));
}

TEST(FilenameEncoding, LeavesInvalidEscapesSafe)
{
	const wxString decoded = UnescapeHTML(wxT("bad%zzname.iso"));
	ASSERT_EQUALS(decoded, RepairFileNameEncoding(decoded));
}

TEST(FilenameEncoding, RepairsJapaneseMojibake)
{
	const wxString broken = wxT("[trance] TC-04-0146-01 \u00e6\u009c\u00ac\u00e5\u00bd\u0093\u00e3\u0081\u00aePrivate Mode part10 Daniel.mp4");
	const wxString repaired = wxT("[trance] TC-04-0146-01 \u672c\u5f53\u306ePrivate Mode part10 Daniel.mp4");
	ASSERT_EQUALS(repaired, RepairFileNameEncoding(broken));
}

TEST(FilenameEncoding, RepairsCjkMojibake)
{
	const wxString broken = wxT("\u00e4\u00b8\u00ad\u00e6\u0096\u0087\u00e6\u00b5\u008b\u00e8\u00af\u0095.txt");
	const wxString repaired = wxT("\u4e2d\u6587\u6d4b\u8bd5.txt");
	ASSERT_EQUALS(repaired, RepairFileNameEncoding(broken));
}
