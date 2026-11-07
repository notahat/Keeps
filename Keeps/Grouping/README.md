# Grouping

The model. `Grouping` holds a folder's group boundaries, how far groups have
been collapsed, the selection, the scroll position, and the picking state:
the group open on the pick screen, the keepers, and which groups are done.
It is what the screens read and change. `GroupLayout` is the pure part:
from the boundaries and the collapse point, it works out the groups, which
are collapsed, and the cells the sort screen shows, one per photo or
collapsed group, leaving out done groups. `Pile` puts a group's photos in
the order a pile of them is drawn, keepers on top. `GridScrollAnchor` is
the sort screen's scroll position, given by the photo at the top of the
view rather than a raw offset, so it survives the cells changing.

`Grouping` converts itself to and from `SavedGrouping`, with `PhotoStems`
translating between photos and the stems keeps.json names them by, but
leaves reading and writing the file to Saving. The folder has no views,
so all of it is covered by unit tests.

This folder uses Saving and Folder.
