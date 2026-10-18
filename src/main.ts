import './styles.css';

// The public pages work without JavaScript. Only the menu and signup preview
// need behavior. No analytics, browser storage, or backend requests are used.
const menuButton = document.querySelector<HTMLButtonElement>('[data-menu-button]');
const navigation = document.querySelector<HTMLElement>('#main-navigation');

if (menuButton && navigation) {
  menuButton.hidden = false;
  document.documentElement.classList.add('has-js');
  const closeMenu = () => menuButton.setAttribute('aria-expanded', 'false');
  menuButton.addEventListener('click', () => {
    menuButton.setAttribute('aria-expanded', String(menuButton.getAttribute('aria-expanded') !== 'true'));
  });
  document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape' && menuButton.getAttribute('aria-expanded') === 'true') {
      closeMenu();
      menuButton.focus();
    }
  });
  navigation.addEventListener('click', (event) => {
    if ((event.target as HTMLElement).closest('a')) closeMenu();
  });
}
