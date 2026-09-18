(() => {
  if (document.querySelector('.lombok-live-scene')) return;
  const scene = document.createElement('div');
  scene.className = 'lombok-live-scene';
  scene.setAttribute('aria-hidden', 'true');
  scene.innerHTML = '<div class="lombok-live-image"></div><div class="lombok-live-sun"></div><div class="lombok-live-shimmer"></div><div class="lombok-live-haze"></div>';
  document.body.prepend(scene);
})();
