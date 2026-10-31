# Saving

keeps.json, the file in each photo folder that records the grouping.
`SavedGrouping` is the format: plain Codable values that refer to photos by
stem. `KeepsFile` reads and writes it, and saves a fresh copy whenever the
observed grouping changes. Alongside the grouping it holds the narrowing:
the keepers, and the done groups by each one's first photo.

Existing keeps.json files must always keep loading, which the hand-written
fixture in `originalFormatRestores` checks. A new optional field, such as
the keepers, needs nothing more: older files simply lack it. Any other
change to the format must add a new name in the file's `"workflow"` field
and convert the old format on load. Uses no other folder.
