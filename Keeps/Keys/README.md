# Keys

Key handling shared by the screens, so they read keys the same way.
`MoveDirection` turns the arrow keys and h/j/k/l into a direction, and
`isPlainLetter` checks a letter key has none of ⌘, ⌃, or ⌥ held, so a
screen's letter keys don't catch menu shortcuts. What a key does is left
to each screen.

Uses no other folder, and has no views.
