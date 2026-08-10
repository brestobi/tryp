(() => {
  document.documentElement.classList.add('js-enabled');

  const button = document.querySelector('[data-menu-button]');
  const nav = document.getElementById('site-nav');

  if (!button || !nav) return;

  const close = () => {
    nav.classList.remove('open');
    button.setAttribute('aria-expanded', 'false');
    button.setAttribute('aria-label', 'Open navigation');
  };

  button.addEventListener('click', () => {
    const isOpen = nav.classList.toggle('open');
    button.setAttribute('aria-expanded', String(isOpen));
    button.setAttribute('aria-label', isOpen ? 'Close navigation' : 'Open navigation');
  });

  nav.querySelectorAll('a').forEach((link) => link.addEventListener('click', close));
})();
