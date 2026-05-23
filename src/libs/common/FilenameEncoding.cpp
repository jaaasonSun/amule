#include "FilenameEncoding.h"

#include <string>
#include <vector>

namespace {

bool IsPlainASCII(const wxString& text)
{
	for (size_t i = 0; i < text.Length(); ++i) {
		if (text[i] > 0x7f) {
			return false;
		}
	}

	return true;
}

bool IsHex(wxChar c)
{
	return (c >= wxT('0') && c <= wxT('9')) ||
	       (c >= wxT('a') && c <= wxT('f')) ||
	       (c >= wxT('A') && c <= wxT('F'));
}

bool LooksPercentEncoded(const wxString& text)
{
	unsigned count = 0;
	for (size_t i = 0; i + 2 < text.Length(); ++i) {
		if (text[i] == wxT('%') && IsHex(text[i + 1]) && IsHex(text[i + 2])) {
			++count;
			i += 2;
		}
	}
	return count >= 2;
}

bool LooksHTMLEntityEncoded(const wxString& text)
{
	for (size_t i = 0; i + 3 < text.Length(); ++i) {
		if (text[i] != wxT('&')) {
			continue;
		}

		const int semicolon = text.find(wxT(';'), i + 1);
		if (semicolon == wxNOT_FOUND || semicolon - static_cast<int>(i) > 12) {
			continue;
		}

		const wxString entity = text.Mid(i + 1, semicolon - i - 1);
		if (entity == wxT("amp") || entity == wxT("lt") || entity == wxT("gt") ||
		    entity == wxT("quot") || entity == wxT("apos")) {
			return true;
		}

		if (entity.Length() >= 2 && entity[0] == wxT('#')) {
			size_t start = 1;
			bool hexadecimal = false;
			if (entity.Length() >= 3 && (entity[1] == wxT('x') || entity[1] == wxT('X'))) {
				start = 2;
				hexadecimal = true;
			}

			if (start >= entity.Length()) {
				continue;
			}

			bool valid = true;
			for (size_t j = start; j < entity.Length(); ++j) {
				if (hexadecimal) {
					valid = valid && IsHex(entity[j]);
				} else {
					valid = valid && entity[j] >= wxT('0') && entity[j] <= wxT('9');
				}
			}
			if (valid) {
				return true;
			}
		}
	}

	return false;
}

int HexValue(wxChar c)
{
	if (c >= wxT('0') && c <= wxT('9')) {
		return static_cast<int>(c - wxT('0'));
	}
	if (c >= wxT('a') && c <= wxT('f')) {
		return static_cast<int>(c - wxT('a')) + 10;
	}
	return static_cast<int>(c - wxT('A')) + 10;
}

int Windows1252ByteFor(wxChar c)
{
	if (c <= 0x00ff) {
		return static_cast<unsigned char>(c);
	}

	switch (c) {
		case 0x20ac: return 0x80;
		case 0x201a: return 0x82;
		case 0x0192: return 0x83;
		case 0x201e: return 0x84;
		case 0x2026: return 0x85;
		case 0x2020: return 0x86;
		case 0x2021: return 0x87;
		case 0x02c6: return 0x88;
		case 0x2030: return 0x89;
		case 0x0160: return 0x8a;
		case 0x2039: return 0x8b;
		case 0x0152: return 0x8c;
		case 0x017d: return 0x8e;
		case 0x2018: return 0x91;
		case 0x2019: return 0x92;
		case 0x201c: return 0x93;
		case 0x201d: return 0x94;
		case 0x2022: return 0x95;
		case 0x2013: return 0x96;
		case 0x2014: return 0x97;
		case 0x02dc: return 0x98;
		case 0x2122: return 0x99;
		case 0x0161: return 0x9a;
		case 0x203a: return 0x9b;
		case 0x0153: return 0x9c;
		case 0x017e: return 0x9e;
		case 0x0178: return 0x9f;
		default:
			if (c >= 0x0100 && c <= 0x01ff) {
				return static_cast<int>(c) - 0x0100 + 0x80;
			}
			return -1;
	}
}

bool IsCommonMojibakeLead(wxChar c)
{
	return c == 0x00c2 || c == 0x00c3 || c == 0x00c4 || c == 0x00c5 ||
	       c == 0x00c6 || c == 0x00c7 || c == 0x00c8 || c == 0x00c9 ||
	       c == 0x00d0 || c == 0x00d1 || c == 0x00e2 || c == 0x00e3 ||
	       c == 0x00e4 || c == 0x00e5 || c == 0x00e6 || c == 0x00e7 ||
	       c == 0x00e8 || c == 0x00e9;
}

bool IsMojibakeByteLike(wxChar c)
{
	return c >= 0x80 && Windows1252ByteFor(c) >= 0;
}

unsigned CountSuspiciousCodepoints(const wxString& text)
{
	unsigned score = 0;

	for (size_t i = 0; i < text.Length(); ++i) {
		const wxChar c = text[i];

		if (c == 0xfffd) {
			score += 4;
			continue;
		}

		if ((c < 0x20) && c != wxT('\t') && c != wxT('\n') && c != wxT('\r')) {
			score += 3;
			continue;
		}

		if (c >= 0x0080 && c <= 0x009f) {
			score += 4;
			continue;
		}

		if (IsCommonMojibakeLead(c) && (i + 1) < text.Length()) {
			const wxChar next = text[i + 1];
			if (next >= 0x00a0 && next <= 0x00bf) {
				score += 4;
			} else if ((next >= 0x0080 && next <= 0x00ff) ||
			           (next >= 0x0100 && next <= 0x01ff)) {
				score += 3;
			}
		}

		if (c == wxT('%') && (i + 2) < text.Length() && IsHex(text[i + 1]) && IsHex(text[i + 2])) {
			score += 1;
		}
	}

	if (LooksHTMLEntityEncoded(text)) {
		score += 2;
		for (size_t i = 0; i < text.Length(); ++i) {
			if (text[i] == wxT('&')) {
				++score;
			}
		}
	}

	return score;
}

bool HTMLEntityReplacement(const wxString& entity, wxString* replacement)
{
	if (entity == wxT("amp")) {
		*replacement = wxT("&");
		return true;
	}
	if (entity == wxT("lt")) {
		*replacement = wxT("<");
		return true;
	}
	if (entity == wxT("gt")) {
		*replacement = wxT(">");
		return true;
	}
	if (entity == wxT("quot")) {
		*replacement = wxT("\"");
		return true;
	}
	if (entity == wxT("apos")) {
		*replacement = wxT("'");
		return true;
	}

	if (entity.Length() < 2 || entity[0] != wxT('#')) {
		return false;
	}

	unsigned value = 0;
	size_t start = 1;
	const bool hexadecimal = entity.Length() >= 3 && (entity[1] == wxT('x') || entity[1] == wxT('X'));
	if (hexadecimal) {
		start = 2;
	}
	if (start >= entity.Length()) {
		return false;
	}

	for (size_t i = start; i < entity.Length(); ++i) {
		if (hexadecimal) {
			if (!IsHex(entity[i])) {
				return false;
			}
			value = (value * 16) + HexValue(entity[i]);
		} else {
			if (entity[i] < wxT('0') || entity[i] > wxT('9')) {
				return false;
			}
			value = (value * 10) + static_cast<unsigned>(entity[i] - wxT('0'));
		}
	}

	if (value == 0 || value > 0x10ffff) {
		return false;
	}

	*replacement = wxString(wxUniChar(value));
	return true;
}

wxString DecodeHTMLEntities(const wxString& text)
{
	if (!LooksHTMLEntityEncoded(text)) {
		return wxString();
	}

	wxString result;
	bool changed = false;
	for (size_t i = 0; i < text.Length(); ++i) {
		if (text[i] != wxT('&')) {
			result += text[i];
			continue;
		}

		const int semicolon = text.find(wxT(';'), i + 1);
		if (semicolon == wxNOT_FOUND || semicolon - static_cast<int>(i) > 12) {
			result += text[i];
			continue;
		}

		wxString replacement;
		const wxString entity = text.Mid(i + 1, semicolon - i - 1);
		if (!HTMLEntityReplacement(entity, &replacement)) {
			result += text[i];
			continue;
		}

		result += replacement;
		i = semicolon;
		changed = true;
	}

	return changed ? result : wxString();
}

wxString RepairMojibakeRuns(const wxString& text)
{
	wxString result;
	bool changed = false;
	for (size_t i = 0; i < text.Length();) {
		if (!IsCommonMojibakeLead(text[i]) || (i + 1) >= text.Length() || !IsMojibakeByteLike(text[i + 1])) {
			result += text[i];
			++i;
			continue;
		}

		std::string bytes;
		const size_t start = i;
		while (i < text.Length()) {
			const int byteValue = Windows1252ByteFor(text[i]);
			if (byteValue < 0) {
				break;
			}

			bytes.push_back(static_cast<char>(byteValue));
			++i;

			if (i >= text.Length()) {
				break;
			}

			const bool currentLooksLikeLead = IsCommonMojibakeLead(text[i]);
			const bool previousWasLead = IsCommonMojibakeLead(text[i - 1]);
			const bool currentContinuesPrevious = previousWasLead && IsMojibakeByteLike(text[i]);
			if (!currentLooksLikeLead && !currentContinuesPrevious) {
				break;
			}
		}

		const wxString candidate(bytes.c_str(), wxConvUTF8, bytes.length());
		if (!candidate.empty()) {
			result += candidate;
			changed = true;
		} else {
			result += text.Mid(start, i - start);
		}
	}

	return changed && result != text ? result : wxString();
}

wxString PercentDecodeUtf8(const wxString& text)
{
	if (!LooksPercentEncoded(text)) {
		return wxString();
	}

	std::string bytes;
	bytes.reserve(text.Length());
	for (size_t i = 0; i < text.Length(); ++i) {
		if (text[i] == wxT('%') && (i + 2) < text.Length() && IsHex(text[i + 1]) && IsHex(text[i + 2])) {
			bytes.push_back(static_cast<char>((HexValue(text[i + 1]) << 4) | HexValue(text[i + 2])));
			i += 2;
			continue;
		}

		if (text[i] > 0x7f) {
			return wxString();
		}
		bytes.push_back(static_cast<char>(text[i]));
	}

	return wxString(bytes.c_str(), wxConvUTF8, bytes.length());
}

wxString ReinterpretLatin1AsUtf8(const wxString& text)
{
	std::string bytes;
	bytes.reserve(text.Length());

	for (size_t i = 0; i < text.Length(); ++i) {
		const wxChar c = text[i];
		const int byteValue = Windows1252ByteFor(c);
		if (byteValue < 0) {
			return wxString();
		}

		bytes.push_back(static_cast<char>(byteValue));
	}

	if (bytes.empty()) {
		return wxString();
	}

	const wxString candidate(bytes.c_str(), wxConvUTF8, bytes.length());
	if (candidate.empty()) {
		return wxString();
	}

	return candidate;
}

bool IsClearlyBetterCandidate(const wxString& original, const wxString& candidate)
{
	if (candidate.empty() || candidate == original) {
		return false;
	}

	const unsigned originalScore = CountSuspiciousCodepoints(original);
	const unsigned candidateScore = CountSuspiciousCodepoints(candidate);

	if (LooksPercentEncoded(original) && !LooksPercentEncoded(candidate) && candidate.Length() <= original.Length()) {
		return true;
	}

	if (LooksHTMLEntityEncoded(original) && !LooksHTMLEntityEncoded(candidate) && candidate.Length() <= original.Length()) {
		return true;
	}

	if (LooksHTMLEntityEncoded(original) && candidate.Length() < original.Length() && candidateScore <= originalScore) {
		return true;
	}

	if (originalScore < candidateScore + 2) {
		return false;
	}

	if ((candidate.Length() * 2) + 4 < original.Length()) {
		return false;
	}

	return true;
}

}

wxString RepairFileNameEncoding(const wxString& fileName, bool* repaired)
{
	if (repaired) {
		*repaired = false;
	}

	if (fileName.IsEmpty()) {
		return fileName;
	}

	wxString current = fileName;
	bool didRepair = false;
	for (unsigned pass = 0; pass < 4; ++pass) {
		std::vector<wxString> candidates;
		const wxString percentCandidate = PercentDecodeUtf8(current);
		if (!percentCandidate.empty()) {
			candidates.push_back(percentCandidate);
		}
		const wxString htmlCandidate = DecodeHTMLEntities(current);
		if (!htmlCandidate.empty()) {
			candidates.push_back(htmlCandidate);
		}
		const wxString runCandidate = RepairMojibakeRuns(current);
		if (!runCandidate.empty()) {
			candidates.push_back(runCandidate);
		}
		if (!IsPlainASCII(current)) {
			const wxString utf8Candidate = ReinterpretLatin1AsUtf8(current);
			if (!utf8Candidate.empty()) {
				candidates.push_back(utf8Candidate);
			}
		}

		wxString best;
		unsigned bestScore = CountSuspiciousCodepoints(current);
		for (std::vector<wxString>::const_iterator it = candidates.begin(); it != candidates.end(); ++it) {
			if (!IsClearlyBetterCandidate(current, *it)) {
				continue;
			}
			const unsigned candidateScore = CountSuspiciousCodepoints(*it);
			if (best.empty() || candidateScore < bestScore) {
				best = *it;
				bestScore = candidateScore;
			}
		}

		if (best.empty()) {
			break;
		}

		current = best;
		didRepair = true;
	}

	if (didRepair && current != fileName && repaired) {
		*repaired = true;
	}

	return didRepair && current != fileName ? current : fileName;
}
