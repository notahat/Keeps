# Keeps

A macOS app for fast culling of RAW/JPEG photo collections.

## Things to look at

Culling:

- Is our structure for passes right?
  - We write a big list of stems to disk for each pass. Is that necessary?
  - Should we just store the picks and rejects for each pass instead?
    - That might make behaviour if you go back and edit a pass more sensible?
- Wider sidebar default/minimum width...fixed width?
- Seems like we write a lot of data each time...performance?
- Is "Commit Pass" the right language?
- Design and spacing of the passes in the sidebar
- Can we let the grid have focus without so much hackery?
- Does serialising deserve its own model?
- Not clear if going back to previous pass and marking/unmarking behaves as expected
- Actual error handling on saving
- Default to have the final pass selected on load
- Should the sidebar be on the right? Check out UI conventions
- Default the sidebar to closed?

General:

- Sort by timestamp from EXIF data
- Handling multiple windows gracefully
- Doing something with the marked files
- Zooming/panning
- IOSurface creation failure messages in console — investigate source (CMPhoto, may be system-level not our code)
- Add a way to view the RAW image
