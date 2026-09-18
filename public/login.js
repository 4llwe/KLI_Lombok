import { signIn, rest } from './api.js';

const form = document.querySelector('#login-form');
const status = document.querySelector('#login-status');

form?.addEventListener('submit', async event => {
  event.preventDefault();

  status.textContent = 'Memeriksa akun…';
  const button = form.querySelector('button[type=submit]');
  button.disabled = true;

  try {
    const data = Object.fromEntries(new FormData(form));
    const session = await signIn(data.email, data.password);

    const [profile] = await rest(
      `profiles?id=eq.${encodeURIComponent(session.user.id)}&select=role,active`
    );

    if (!profile || !profile.active) {
      throw new Error('Akun tidak aktif atau profil tidak ditemukan.');
    }

    const internalRoles = [
      'instructor',
      'academic',
      'admin',
      'finance',
      'executive',
      'superadmin'
    ];

    location.href = internalRoles.includes(profile.role)
      ? '/admin.html'
      : '/portal.html';
  } catch (error) {
    status.textContent = error.message;
  } finally {
    button.disabled = false;
  }
});
