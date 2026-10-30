# Saving

keeps.json, the file in each photo folder that records the grouping.
`SavedGrouping` is the format: plain Codable values that refer to photos by
stem. `KeepsFile` reads and writes it, and saves a fresh copy whenever the
observed grouping changes.

Existing keeps.json files must always keep loading. The file names its
format in its `"workflow"` field, and a change to the format must add a new
name and convert the old one on load, with a test that restores a
hand-written file in the old format (see `originalFormatRestores`). Uses no
other folder.
