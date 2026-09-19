(() => {
  if (document.querySelector('.lombok-live-scene')) return;

  const scene = document.createElement('div');
  scene.className = 'lombok-live-scene';
  scene.setAttribute('aria-hidden', 'true');

  const isHomepage = document.body.classList.contains('home-page');
  let mainVideo = null;

  if (isHomepage) {
    scene.classList.add('lombok-main-scene');
    ['bg', 'sun', 'shimmer', 'haze'].forEach((layer) => {
      const item = document.createElement('div');
      item.className = `lombok-main-${layer}`;
      scene.appendChild(item);
    });
  } else {
    mainVideo = document.createElement('video');
    mainVideo.className = 'lombok-live-video';
    mainVideo.src = 'assets/lombok-photo-living.mp4';
    mainVideo.poster = 'assets/lombok-photo-living-poster.jpg';
    mainVideo.autoplay = true;
    mainVideo.muted = true;
    mainVideo.loop = true;
    mainVideo.playsInline = true;
    mainVideo.preload = 'metadata';
    mainVideo.setAttribute('tabindex', '-1');

    const shade = document.createElement('div');
    shade.className = 'lombok-live-shade';
    scene.append(mainVideo, shade);
  }

  document.body.prepend(scene);

  const footerVideos = [];
  document.querySelectorAll('footer').forEach((footer) => {
    if (footer.querySelector('.footer-living-media')) return;
    const media = document.createElement('div');
    media.className = 'footer-living-media';
    media.setAttribute('aria-hidden', 'true');

    const flowerVideo = document.createElement('video');
    flowerVideo.className = 'footer-living-video';
    flowerVideo.src = 'assets/bunga-living.mp4';
    flowerVideo.poster = 'assets/bunga-living-poster.jpg';
    flowerVideo.autoplay = true;
    flowerVideo.muted = true;
    flowerVideo.loop = true;
    flowerVideo.playsInline = true;
    flowerVideo.preload = 'metadata';
    flowerVideo.setAttribute('tabindex', '-1');

    const flowerShade = document.createElement('div');
    flowerShade.className = 'footer-living-shade';
    media.append(flowerVideo, flowerShade);
    footer.prepend(media);
    footerVideos.push(flowerVideo);
  });

  const allVideos = [mainVideo, ...footerVideos].filter(Boolean);
  const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)');
  const syncMotion = () => {
    allVideos.forEach((item) => {
      if (reducedMotion.matches) {
        item.pause();
        item.removeAttribute('autoplay');
      } else {
        item.autoplay = true;
        item.play().catch(() => item.closest('div')?.classList.add('video-paused'));
      }
    });
  };

  syncMotion();
  reducedMotion.addEventListener?.('change', syncMotion);
})();
