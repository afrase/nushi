# 0018. The app is Nushi

The first build is retired, so the rebuild drops "Next": app name "Nushi", bundle ID `com.nushihq.Nushi`, data folder `~/Library/Application Support/Nushi`. It replaces [0011](0011-nushi-next-identity.md).

The daemon moves the old "Nushi Next" data folder once, at its first start, if the new one doesn't exist (`cmd/nushid/rename.go`); the app stops the old daemon first. Chats in scratch folders get the new paths, and Claude's history of their sessions is copied to the new paths' history folders (Claude files history by folder path), as moves do ([0014](0014-moving-a-chat-forks-it.md)). The old copies stay.

The first build used the same bundle ID; running it again would share the app's macOS preferences (only window state; the app keeps its own settings in the data folder).
