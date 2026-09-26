/* Progressive UI enhancement. Native forms retain their existing endpoints and CSRF fields. */
document.addEventListener('DOMContentLoaded', () => {
  const nav = document.getElementById('mobileNav');
  const toggle = document.querySelector('.header-toggle');
  if (nav && toggle) {
    const panel = nav.querySelector('.mobile-nav-panel');
    panel.setAttribute('role', 'dialog'); panel.setAttribute('aria-modal', 'true'); panel.setAttribute('aria-label', 'Navigation');
    new MutationObserver(() => {
      const open = nav.classList.contains('open');
      toggle.setAttribute('aria-expanded', String(open));
      if (open) panel.querySelector('button, a')?.focus(); else toggle.focus();
    }).observe(nav, { attributes: true, attributeFilter: ['class'] });
    nav.addEventListener('keydown', e => {
      if (e.key === 'Escape') { nav.classList.remove('open'); document.body.style.overflow = ''; }
      if (e.key === 'Tab') {
        const items = [...panel.querySelectorAll('a,button')];
        if (e.shiftKey && document.activeElement === items[0]) { e.preventDefault(); items.at(-1).focus(); }
        else if (!e.shiftKey && document.activeElement === items.at(-1)) { e.preventDefault(); items[0].focus(); }
      }
    });
  }
  const savedSearch = document.getElementById('saveSearchForm');
  if (savedSearch) {
    const status = document.createElement('p'); status.setAttribute('role', 'status');
    status.style.marginTop = '12px'; savedSearch.append(status);
    savedSearch.addEventListener('submit', async e => {
      e.preventDefault();
      const button = savedSearch.querySelector('button[type="submit"]');
      if (button.disabled) return;
      button.disabled = true; status.textContent = 'Saving your search…';
      try {
        const response = await fetch(savedSearch.action, {
          method: 'POST', body: new URLSearchParams(new FormData(savedSearch)),
          credentials: 'same-origin', headers: {Accept: 'application/json'}
        });
        if (response.redirected || !response.headers.get('content-type')?.includes('application/json')) throw new Error('Please sign in again, then retry saving your search.');
        const result = await response.json();
        if (!response.ok) throw new Error(result.error || 'Unable to save your search. Please try again.');
        status.textContent = result.message; button.textContent = 'Search saved';
      } catch (error) { status.textContent = error.message || 'Unable to save your search.'; button.disabled = false; }
    });
  }
  const form = document.querySelector('[data-search-form]');
  if (form) {
    const progress = document.createElement('div');
    progress.className = 'search-progress'; progress.hidden = true;
    progress.setAttribute('role', 'status'); progress.setAttribute('aria-live', 'polite');
    progress.innerHTML = '<div><div class="search-spinner" aria-hidden="true"></div><h2>Searching for matches…</h2><p>Comparing your details with response records.</p></div>';
    document.body.append(progress);
    form.addEventListener('submit', () => { if (form.checkValidity()) { progress.hidden = false; form.setAttribute('aria-busy', 'true'); } });
    window.addEventListener('pageshow', () => { progress.hidden = true; form.removeAttribute('aria-busy'); });
  }
});
