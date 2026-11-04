# 0018. The app is Nushi

The first build is retired, so the rebuild drops "Next": app name "Nushi", bundle ID `com.nushihq.Nushi`, data folder `~/Library/Application Support/Nushi`. It replaces [0011](0011-nushi-next-identity.md).

The daemon moved the old "Nushi Next" data folder once, at its first start, if the new one didn't exist; the app stopped the old daemon first. Chats in scratch folders got the new paths, and Claude's history of their sessions was moved to the new paths' history folders (Claude files history by folder path). That migration was removed on 2026-11-05, once every Mac that ran Nushi Next had moved: a "Nushi Next" folder left now is just ignored.

The first build used the same bundle ID; running it again would share the app's macOS preferences (only window state; the app keeps its own settings in the data folder).
