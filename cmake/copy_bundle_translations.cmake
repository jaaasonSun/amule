if (NOT DEFINED PO_DIR OR NOT DEFINED BUNDLE_DIR)
	message (FATAL_ERROR "PO_DIR and BUNDLE_DIR are required")
endif()

if (NOT EXISTS "${PO_DIR}")
	message (STATUS "No translation build directory found at ${PO_DIR}")
	return()
endif()

file (GLOB GMO_FILES "${PO_DIR}/*.gmo")

if (NOT GMO_FILES)
	message (STATUS "No .gmo files found in ${PO_DIR}")
	return()
endif()

foreach (GMO_FILE ${GMO_FILES})
	get_filename_component (LANG "${GMO_FILE}" NAME_WE)
	set (LANG_DIR "${BUNDLE_DIR}/SharedSupport/locale/${LANG}/LC_MESSAGES")
	file (MAKE_DIRECTORY "${LANG_DIR}")
	file (COPY "${GMO_FILE}" DESTINATION "${LANG_DIR}")
	file (RENAME "${LANG_DIR}/${LANG}.gmo" "${LANG_DIR}/amule.mo")
endforeach()
