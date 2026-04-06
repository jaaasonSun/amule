#ifndef FILENAME_ENCODING_H
#define FILENAME_ENCODING_H

#include <wx/string.h>

wxString RepairFileNameEncoding(const wxString& fileName, bool* repaired = 0);

#endif
