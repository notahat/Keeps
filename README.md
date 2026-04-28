# Keeps

A macOS app for fast culling of RAW/JPEG photo collections.

## Things to look at

Culling:

- Inefficiencies in our new pass structure? Are we recalculating things too much?
- Seems like we write a lot of data each time...performance? Background task? Periodic writes?
- Can we let the grid have focus without so much hackery?
- Edge case of marking something that has already been marked in a later pass
- Actual error handling on saving
- Have a way to delete the last pass
  - Probably not earlier passes. Would that even make sense/

General:

- Handling multiple windows gracefully
- Doing something with the marked files
- Zooming/panning
- IOSurface creation failure messages in console — investigate source (CMPhoto, may be system-level not our code)
- Add a way to view the RAW image
