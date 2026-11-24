# Jira

Nushi shows your Jira Cloud issues next to your chats. You can see what's on your plate, move an issue along, and start an agent on an issue, on its own branch, in a couple of clicks.

![The Jira view: a sprint's issues grouped by status](https://raw.githubusercontent.com/afrase/nushi/main/docs/images/jira.png)

## Connect your Jira site

You need three things:

- your site's address, such as `example.atlassian.net`;
- the email you sign in to Jira with;
- an API token (classic or scoped).

Make the token on Atlassian's site: click **Make a token** in Nushi's form, or go to [id.atlassian.com/manage-profile/security/api-tokens](https://id.atlassian.com/manage-profile/security/api-tokens). Paste it only into that form, never into a chat.

1. Open **Settings** (at the bottom of the sidebar, or ⌘,) and pick **Jira**.
2. The **Add a Jira Cloud site** form opens. If you already have a site, click **Add a site** first.
3. Fill in **Site**, **Email** and **API token**. **Expires** is optional: give the token's end date to get a warning before it runs out.
4. Click **Add**.

Nushi checks the token with Jira, then the site's row says **Connected**, with your name and email. To disconnect a site, click **⋯** beside it, then **Remove site…**.

## Open your issues

Press ⌘J, click **Jira** at the bottom of the sidebar, or choose **View › Jira**. Jira takes the chat's place. To go back to your chats, press Esc or click the close button.

The tabs at the top pick which issues you see:

- **Mine**: your open issues.
- **Sprint**: the active sprint of a board. The first time, click **Pick the board…** and choose one.
- **JQL**: type a Jira search (JQL is Jira's search language). It suggests fields, operators and values as you type. Press Return to run it. To keep it as a tab of its own, click **Save…**.

Issues are grouped into a card per status. Click a card's title to fold it, or drag the card to reorder. Nushi remembers both.

On **Sprint**, **JQL** and saved searches, the menu at the right (**Everyone**) narrows the list to **Me**, **Unassigned**, or one person.

If you have more than one site, the menu next to the **Jira** title switches sites. **All sites** shows your open issues from every site at once.

## Start work on an issue

This starts an agent on the issue in a worktree. A worktree is a second checkout of your repository on its own branch, so the agent's work doesn't touch the branch you have open.

1. Hover over the issue's row and click the play button at its end. You can also select the row and press ⌘⏎, or right-click it and pick **Start work**.
2. Pick a recent folder from the menu, or **Choose folder…** to pick your repository.
3. The **New chat** dialog opens with the issue already picked. It says **In a new worktree on** and shows the branch name. The name comes from the issue's key and summary (for example `PROJ-123-fix-the-login`).
4. Pick an agent and press Return.

Before step 4, you can press:

- **W** to skip the worktree and work in the folder itself.
- **B** to rename the branch.
- ⌫ to drop the issue.

The chat shows the issue's key in the sidebar. Nushi tells the agent which issue it's on, but adds nothing to your message. Tell the agent what you want, as usual.

You can also attach an issue from the **New chat** dialog itself. Press **I**, then paste the issue's link, type its key, or search by words.

## Look at an issue

Click a row to see the issue's details: description, subtasks, links, attachments, comments, and the chats already started on it. From there you can comment (Markdown works), click **Start work**, or open the issue in your browser. Press Esc to return to the list.

## Move an issue

Click an issue's status, on its row or in its details, and pick a move. The list shows only the moves Jira allows. If a move needs more fields, Nushi asks for them.

## Keys

| Key | What it does |
| --- | --- |
| ⌘J | Open or close Jira |
| ↑ ↓ or j k | Select an issue |
| Return | Show its details |
| ⌘⏎ | Start work on it |
| ⌘R | Refresh |
| / | Jump to the JQL search |
| ⌥⌘1–9 | Switch to the first to ninth tab |
| Esc | Back to the list, then close |

On Linux, use Ctrl wherever the Mac uses ⌘. The one exception: ⌥⌘1–9 is Alt+1–9.

## Good to know

- Your token is kept in your Mac's keychain (the keyring on Linux), never in a file. **Remove site…** deletes it from there. If the keychain won't let it (a dismissed prompt, no keyring), the site still goes, and the token stays there. Nushi says so in a note naming the item ("Nushi: Jira API token for" and the site) for you to delete there.
- If Nushi says it needs your OK to read the token (for example, after an update), click **Allow…** and enter your password when asked. If it offers **Restart daemon** instead, click that. Restarting stops running turns and closes terminals.
- The list refreshes every minute while it's open, showing the last results while new ones load. It waits while an issue is open over it or Nushi's window is in the background, and refreshes once when you come back.
- If a refresh fails, the last results stay and the bar says **Couldn't refresh · as of** when they're from.
- A chat started on an issue gives the agent tools for that one issue: it can read it, comment on it, and move it. The agent's own permission mode decides whether it asks you first. The issue's details show which comments and moves came from an agent.
- If you gave an expiry date, Nushi warns you two weeks before the token runs out. Make a new token and add the site again.
