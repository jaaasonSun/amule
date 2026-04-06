#include "FilenameEncoding.h"

#include <string>

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
			score += 2;
			continue;
		}

		if ((c == 0x00c2 || c == 0x00c3 || c == 0x00c5) && (i + 1) < text.Length()) {
			const wxChar next = text[i + 1];
			if (next >= 0x00a0 && next <= 0x00bf) {
				score += 2;
			} else if (next >= 0x0080 && next <= 0x00ff) {
				score += 1;
			}
		}

		if (c >= 0x00e0 && c <= 0x00ef) {
			if ((i + 1) < text.Length()) {
				const wxChar next = text[i + 1];
				if ((next >= 0x0080 && next <= 0x00bf) ||
				    (next >= 0x0100 && next <= 0x01ff)) {
					score += 2;
				}
			}
		}
	}

	return score;
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

	if (fileName.IsEmpty() || IsPlainASCII(fileName)) {
		return fileName;
	}

	const wxString candidate = ReinterpretLatin1AsUtf8(fileName);
	if (!IsClearlyBetterCandidate(fileName, candidate)) {
		return fileName;
	}

	if (repaired) {
		*repaired = true;
	}

	return candidate;
}
