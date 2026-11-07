# Done

The done screen, which the user reaches by clicking the set-aside pile in
the sidebar: the done groups, latest first, each drawn as a pile with how
many of its photos were kept. `DoneScreen` draws them and handles input:
clicking selects a group, and double-clicking or Return opens it on the
pick screen, where the user can change it or mark it not done. Arrow keys
don't move the selection.

This folder uses Grouping, Images, Folder, and Keys, and never another
screen's folder: Sort, Pick, Done, and Keepers don't use each other.
