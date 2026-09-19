# Video background update

The website background now uses `public/assets/lombok-photo-living.mp4`.

Implementation details:
- muted, looping, inline autoplay;
- responsive `object-fit: cover` presentation;
- poster image fallback at `public/assets/lombok-photo-living-poster.jpg`;
- reduced-motion support pauses and hides the video while retaining the poster;
- the existing translucent content layers preserve text contrast.

Files changed:
- `public/living-background.js`
- `public/styles.css`
- `public/assets/lombok-photo-living.mp4`
- `public/assets/lombok-photo-living-poster.jpg`
