# Folder

Turns a folder on disk into the list of photos the app works with.
`FolderScanner` finds the RAW and JPEG files, pairs a RAW and a JPEG that
share a filename stem into one `PhotoItem`, and sorts them by creation date.
`FolderSession` holds the result for one open folder.

A photo has two identities: an in-memory `id`, used everywhere at runtime,
and its `stem`, used in keeps.json so saved work survives relaunches and
folder moves. This folder doesn't load image data, hold the grouping, or
manage sandbox access, and it uses no other folder.
