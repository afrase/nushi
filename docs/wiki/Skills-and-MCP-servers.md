# Skills and MCP servers

A **skill** is a short set of instructions an agent picks up when a task needs it, like "how we write release notes". An **MCP server** is a small program that gives an agent extra tools, like reading a database. Nushi lists the ones your agents already have, so you can check them, switch them off and tidy them up in one place.

## Open them

- Click **Settings** at the bottom of the sidebar (or press ⌘, — Ctrl+, on Linux), then **Skills** or **MCP servers**.
- From a chat, open its **⋯** menu and pick **Skills…** or **MCP servers…**. The page opens on that chat's folder. **MCP servers…** shows only for Claude and Ante chats.

## See an agent's skills

1. Go to **Settings › Skills**.
2. Next to **For**, pick the agent. Next to **in**, pick the folder.
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
3. Claude's servers are grouped by where they're saved: **User** (yours, every folder), **Project** (the repository's, shared with everyone on it), **Local** (yours, this project only), **Plugins** and **claude.ai**. Ante's servers have their own list.

Each server shows its state, such as **Connected**, **Failed to connect**, **Needs login** or **Off**. **Check again** checks them all. For **Needs login**, click **Log in** and finish in your browser.

## Add, edit or remove a server

1. Click **Add server**, then pick the agent: **For Claude…** or **For Ante…**.
2. Enter a **Name**. For Claude, pick a **Scope**: **User**, **Project** or **Local**.
3. Pick a **Transport**. For **stdio**, enter the **Command** and the **Arguments, one per line**. For **HTTP** or **SSE**, enter the **URL**. Ante doesn't offer SSE.
4. Click **Add**.

Have a config to paste? Click **Edit as JSON**. To change a server later, use **⋯ › Edit…** or **⋯ › Remove…** on its row.

## Turn a server off

Claude's User, Project and Local servers have a switch marked **in this project**. A new Project server says **Waiting for approval** and shows **Approve** and **Reject** until you pick one.

Plugin servers go on and off with their plugin, under **Settings › Skills › Plugins**. Plugin servers and claude.ai connectors say **Off only with /mcp in a terminal**: Nushi can't switch them one by one. Ante has no off switch, so remove the server instead.

A running chat keeps its servers until it restarts. After a change, the chat's **MCP** widget in the details panel says **Applies when the chat restarts**. Click **Reload** there to restart the chat now.

## Which agents this covers

| | Skills | MCP servers |
|---|---|---|
| Claude | Yes | Yes |
| Ante | Yes | Yes (yours only) |
| Codex, OpenCode, Pi, PiG, oh-my-pi | Yes | Not listed: change them with the agent itself |

## Good to know

- Changed something in a terminal? Click **Refresh** on Skills or **Check again** on MCP servers.
- A greyed-out switch is set in another file. Hover over it to see which one.
- A Claude server with a URL has **⋯ › Log out**, which forgets its sign-in.
- Claude and Codex chats also get a few tools from Nushi itself, such as opening a file in the preview. They don't show in these lists.
- To see which agents Nushi found, or to set up Codex, open **Settings › Agents**. [Getting started](Getting-started) walks through it.
