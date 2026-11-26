# Skills and MCP servers

A **skill** is a short set of instructions an agent picks up when a task needs it, like "how we write release notes". An **MCP server** is a small program that gives an agent extra tools, like reading a database. Nushi lists the ones your agents already have, so you can check them, switch them off and tidy them up in one place.

## Open them

- Click **Settings** at the bottom of the sidebar (or press ⌘,, or Ctrl+, on Linux), then **Skills** or **MCP servers**.
- From a chat, open its **⋯** menu and pick **Skills…** or **MCP servers…**. The page opens on that chat's folder. **MCP servers…** shows only for Claude, Ante and PiG chats.

## See an agent's skills

1. Go to **Settings › Skills**.
2. Next to **For**, pick the agent. It starts on the chat's agent, or with no chat on the agent a new chat would use. Next to **in**, pick the folder.
3. Skills are grouped: **Yours** (every folder), **This project**, **Shared**, and the agent's own. Claude also shows **Built in**, a group for each plugin, and **Plugins**.

Each skill shows its description and roughly how many tokens it adds to every chat. Type in the search box to filter the list.

## Switch a skill off

Flip the switch on its row. The words next to it say where the change is saved, such as **everywhere** or **in this project**. Running chats pick up the change when they restart.

A plugin's skill says **with its plugin**. Switch the plugin off under **Plugins** instead. A plugin you installed for yourself also has **⋯ › Uninstall…**.

## Open or delete a skill

Click **⋯** at the end of a skill's row:

- **Open SKILL.md** opens the skill's file in your text editor.
- **Show in Finder** (**Show in Folder** on Linux) shows where it is.
- **Delete…** moves it to the Trash. For a shared skill, the dialog says which agents lose it. It isn't offered for skills that came with the agent or a plugin.

## Share a skill with Claude

The **Shared** group holds skills that several agents read. Each row lists the agents that load it. Claude doesn't read this group yet, so with Claude picked its rows say **Not read by Claude**. To give a skill to Claude too, pick **⋯ › Link for Claude…**, then **Link**. Nushi adds a link where Claude looks; the skill stays where it is.

## Write a new skill

Click **New skill…**. Nushi opens a new chat with the picked agent and puts a request to write a skill in the message box. Read it, change it if you like, and send it. For Claude you first pick **In .agents/skills** (shared with the other agents) or **In .claude/skills** (Claude only).

## See MCP servers

1. Go to **Settings › MCP servers**.
2. Next to **In**, pick the folder.
3. Claude's servers are grouped by where they're saved: **User** (yours, every folder), **Project** (the repository's, shared with everyone on it), **Local** (yours, this project only), **Plugins** and **claude.ai**. Ante's and PiG's servers have their own lists. PiG's are **User** (yours) and **Project** (this folder's `.pig/mcp.json`). Nushi writes PiG's files only when you change something here.

Each server shows its state, such as **Connected**, **Failed to connect**, **Needs login** or **Off**. **Check again** checks them all. In a folder that brings code Claude would run and nobody trusted yet, Claude's servers show **Not checked**: checking runs Claude there, so start a chat in the folder and choose **Start anyway** first. Where Nushi asks about the folder on every start (it can't read or vouch for its settings), the servers stay unchecked. For **Needs login**, click **Log in** and finish in your browser.

A PiG **Project** server says **Folder not trusted** until you trust the folder in PiG: run `pig` in that folder in a terminal and trust it when it asks, or type `/trust` there. Then click **Check again**.

## Add, edit or remove a server

1. Click **Add server**, then pick the agent: **For Claude…**, **For Ante…** or **For PiG…**.
2. Enter a **Name**. Pick a **Scope**: **User**, **Project** or **Local** for Claude, **User** or **Project** for PiG.
3. Pick a **Transport**. For **stdio**, enter the **Command** and the **Arguments, one per line**. For **HTTP** or **SSE**, enter the **URL** and any **Headers**. Only Claude offers SSE. Ante sends headers only from version 0.2.15 on: on an older Ante, run `ante update` first.
4. Click **Add**.

Have a config to paste? Click **Edit as JSON**. To change a server later, use **⋯ › Edit…** or **⋯ › Remove…** on its row. Secret values show as ••••: they stay as they are if you change nothing else, else type them again. A server whose OAuth settings hide something says so under its URL: change it with **Edit as JSON**, where those settings are.

## Turn a server off

Claude's User, Project and Local servers have a switch marked **in this project**. A new Claude Project server says **Waiting for approval** and shows **Approve** and **Reject** until you pick one.

PiG's switches write PiG's own files, and only when you flip one. On one of your servers it's marked **in every folder**: it turns the server on or off in your own `mcp.json`, for every folder, for you only. On a Project server it's marked **in this project**: it changes the folder's `.pig/mcp.json`, which everyone on the repository shares. Hover over a switch to see the file. Where the folder's own `.pig/mcp.json` sets one of yours, its switch is greyed out and the row says so: change that file instead.

Plugin servers go on and off with their plugin, under **Settings › Skills › Plugins**. Plugin servers and claude.ai connectors say **Off only with /mcp in a terminal**: Nushi can't switch them one by one. Ante has no off switch, so remove the server instead.

A running chat keeps its servers until it restarts. After a change, the chat's **MCP** widget in the details panel says **Applies when the chat restarts**. Click **Reload** there to restart the chat now.

## Which agents this covers

| | Skills | MCP servers |
|---|---|---|
| Claude | Yes | Yes |
| Ante | Yes | Yes (yours only) |
| PiG | Yes | Yes |
| Codex, OpenCode, Pi, oh-my-pi | Yes | Not listed: change them with the agent itself |

## Good to know

- Changed something in a terminal? Click **Refresh** on Skills or **Check again** on MCP servers.
- A greyed-out switch is set in another file. Hover over it to see which one.
- A server with a URL has **⋯ › Log out**, which forgets its sign-in. Ante needs 0.2.15 or later for it; an older one says to update.
- Claude and Codex chats also get a few tools from Nushi itself, such as opening a file in the Files pane. They don't show in these lists.
- To see which agents Nushi found, or to set up Codex, open **Settings › Agents**. [Getting started](Getting-started) walks through it.
