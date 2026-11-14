# 0120. Each project sorts its own way

Status: accepted, 2026-11-14.

## Context
The sidebar's Arrange menu (ADR 0089) had one Sort by for every project. Claude's desktop app has a "Group and sort" button (up and down arrows) on each project's header, beside its +, so one project can be sorted by when its chats were last updated while another keeps its hand-made order. The owner wants the same.

## Decision
- **Sorting is a project's own choice**: a Sort button (`ProjectSortButton`, `project_sort.dart`, `LineIcon.sort`: an arrow up beside an arrow down) on each project's header, before its +, opens Manual, Last updated, Date created and Name, their two ways while it isn't Manual, and Sidebar’s sort. It shows under the pointer, with the focus or while its menu is open, as the + does, and always, in the accent ink, while the project sorts its own way, so a list sorted otherwise than the rest says so. Its tooltip is "Sort this project", not Claude's "Group and sort": a project here doesn't group its chats.
- **The pref is kept by project** (`projectSorts`, `app.json`'s `projectSorts`: by folder path, `{"sort": "updated", "ascending": true}`); a project without an entry sorts as the sidebar does. Remove from sidebar (`forgetProject`) forgets the project's entry; Reset to defaults clears them all.
- **The sidebar's Sort by stays, as the default** (`sidebarSort`, `sidebarAscending`): it sorts the projects that haven't picked their own, the sections, and the groups of the other groupings. An existing user's choice is that default, so nothing they see changes until they pick a project's own. Its submenu says a project's ⇅ sorts it its own way.
- **Grouping stays global**: grouping by project is what makes the headers the button lives on; another grouping has no projects to sort apart, and their own sorts wait unused until it's Project again.
- **Show stays global**: what a row shows (its state, agent, branch, project, time) is one look down the list; rows that showed different parts in each project would read as different kinds of rows. A row's time is the one its project sorts by (made or updated).
- A project's chats drag into an order of their own only while it sorts by hand (Manual), as the sidebar's did.

## Consequences
- Amends 0089 (Sort by is the default for projects that don't pick their own).
