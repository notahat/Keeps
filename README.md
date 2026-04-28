# Keeps

A macOS app for fast culling of RAW/JPEG photo collections.

## Things to look at

Culling:

- Inefficiencies in our new pass structure? Are we relculating things too much?
- Wider sidebar default/minimum width...fixed width?
- Seems like we write a lot of data each time...performance?
- Is "Commit Pass" the right language?
- Design and spacing of the passes in the sidebar
- Can we let the grid have focus without so much hackery?
- Does serialising deserve its own model?
- Edge case of marking something that has already been marked in a later pass
- Actual error handling on saving
- Should the sidebar be on the right? Check out UI conventions
- Default the sidebar to closed?

General:

- Sort by timestamp from EXIF data
- Handling multiple windows gracefully
- Doing something with the marked files
- Zooming/panning
- IOSurface creation failure messages in console — investigate source (CMPhoto, may be system-level not our code)
- Add a way to view the RAW image
