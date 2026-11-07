# Keys

Key and click handling shared by the screens, so they read input the
same way. `MoveDirection` turns the arrow keys and h/j/k/l into a direction, and
`isPlainLetter` checks a letter key has none of ⌘, ⌃, or ⌥ held, so a
screen's letter keys don't catch menu shortcuts. `handlesKeys` sets up a
screen's view to take focus and keys, and `onClick` tells a click from a
double click without making the single click wait. Each screen defines
what its keys and clicks do.

The code here has no views of its own.

This folder uses no other folder.
