
## 2026-05-14 - prefs connection backend
- Connection preferences GET uses EC_OP_GET_PREFERENCES with EC_TAG_SELECT_PREFS=EC_PREFS_CONNECTIONS and reads EC_TAG_CONN_MAX_DL/EC_TAG_CONN_MAX_UL from EC_TAG_PREFS_CONNECTIONS.
- SET must send EC_OP_SET_PREFERENCES with EC_DETAIL_FULL and only the EC_TAG_CONN_MAX_DL/EC_TAG_CONN_MAX_UL child tags; EC_DETAIL_FULL prevents absent boolean connection prefs from being treated as false by CEC_Prefs_Packet::Apply().
- Swift package tests link the static bridge core from build-native-bridge and may require a clean/relink after the static library changes.
- PreferencesWindowView now lives in its own file; the extracted view keeps the same imports and private limitField helper, so SecondaryWindows.swift can be removed once it only held that code.
