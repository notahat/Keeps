# Grouping

The model. `Grouping` holds a folder's group boundaries, how far groups have
been collapsed, the selection, and the scroll position, and is what the
screens read and change. `GroupLayout` is the pure part: from the boundaries
and the collapse point, it works out the groups, which are collapsed, and
the cells the sort screen shows, one per photo or collapsed group.

`Grouping` converts itself to and from `SavedGrouping`, translating between
photo ids and the stems keeps.json uses, but leaves reading and writing the
file to Saving. Uses Saving and Folder, and has no views, so all of it is
covered by unit tests.
