# KeyHeat

A macOS menu bar app that counts every key you press and shows which ones you
use most as a heatmap over a Mac keyboard.

It runs in the background and lives in the menu bar. Open the dashboard to see:

- A heatmap overlay on the keyboard, blue for rarely used keys through to red for
  the hottest, over today, the last 7 or 30 days, or all time. Switch the
  board to Dvorak to see where the same typing would land there, or narrow
  the whole dashboard to the letters and , . / ; ' to see how often you use
  each one.
- Your most and least pressed keys, presses per day, and left vs right hand balance.
- Modifier keys too: ⌘ ⌥ ⌃ ⇧ fn and caps lock, left and right counted
  separately.

Only counts are stored, per key and per hour, in a local SQLite file. The
order you typed keys in is never recorded, so nothing can be turned back into
text, and nothing leaves your Mac.

Written in Swift and SwiftUI. Needs macOS 14 or later.

## Running it

``` bash
make run  # to build from source
```
or
``` bash
make install  # to move to /Applications
```

This builds the app, wraps it in `build/KeyHeat.app`, and opens it. On first
launch macOS asks for Input Monitoring permission (System Settings → Privacy &
Security → Input Monitoring); counting starts as soon as it is granted.
`make install` copies the app to `/Applications`.
