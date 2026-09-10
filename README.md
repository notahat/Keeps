# Keeps

A macOS app for fast culling of RAW/JPEG photo collections.

## Things to look at

- Doing something with the marked files
- Handling multiple windows gracefully
- Zooming/panning
- Add a way to view the RAW image
- Can we let the grid have focus without so much hackery?
- IOSurface creation failure messages in console — investigate source (CMPhoto, may be system-level not our code)
- Opening a folder with no photos in it leaves you at the "Open a folder of photos to get started" message...confusing
  - Maybe we should not open a window unless its attached to a folder of photos
