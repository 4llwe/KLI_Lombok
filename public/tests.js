import { getConfig, getSession } from './api.js';

const root = document.querySelector('#test-catalog');
let data = [];
let activeLanguage = 'all';
const esc = value => String(value ?? '').replace(/[&<>'"]/g, char => ({ '&':'&amp;', '<':'&lt;', '>':'&gt;', "'":'&#39;', '"':'&quot;' }[char]));
const translate = text => window.KLII18n?.t(text) ?? text;
const testTypeLabels = {
  placement: 'Placement test', progress: 'Progress test', final: 'Final test',
  certification_readiness: 'Certification readiness', skill_check: 'Skill check'
};

function render(language = activeLanguage) {
  activeLanguage = language;
  const rows = language === 'all' ? data : data.filter(item => item.language === language);
  root.innerHTML = rows.map(test => `
    <article class="portal-panel test-card">
      <div class="panel-head"><span class="tag">${esc(test.language)} · ${esc(test.level)}</span><small>${esc(test.duration_minutes)} ${esc(translate('menit'))}</small></div>
      <h2>${esc(test.title)}</h2><p>${esc(test.description)}</p>
      <div class="pathway"><span>${esc(test.framework)}</span><span>${esc(testTypeLabels[test.test_type] || test.test_type)}</span><span>${esc(translate('Standar lulus'))} ${esc(test.pass_score)}%</span><span>${test.validation_status === 'validated' ? 'Validated' : esc(translate('Latihan/diagnostik'))}</span></div>
      <a class="button full" href="${getSession()?.access_token ? `take-test.html?testId=${encodeURIComponent(test.id)}` : 'login.html'}">${esc(translate(getSession()?.access_token ? 'Mulai tes' : 'Masuk untuk mengikuti'))}</a>
    </article>`).join('') || `<div class="empty-state"><p>${esc(translate('Belum ada tes pada filter ini.'))}</p></div>`;
}

document.querySelectorAll('[data-language]').forEach(button => {
  button.addEventListener('click', () => {
    document.querySelectorAll('[data-language]').forEach(item => item.classList.remove('active'));
    button.classList.add('active');
    render(button.dataset.language);
  });
});
window.addEventListener('kli-languagechange', () => render());

try {
  const config = await getConfig();
  const response = await fetch(`${config.supabaseUrl}/rest/v1/assessment_tests?published=eq.true&order=language.asc,level.asc&select=id,language,framework,level,test_type,title,description,duration_minutes,pass_score,review_status,validation_status`, {
    headers: { apikey: config.supabaseAnonKey, Authorization: `Bearer ${config.supabaseAnonKey}`, Accept: 'application/json' },
    cache: 'no-store'
  });
  const payload = await response.json().catch(() => null);
  if (!response.ok) throw new Error(payload?.message || payload?.hint || 'Katalog tes belum dapat dimuat.');
  data = Array.isArray(payload) ? payload : [];
  render();
} catch (error) {
  root.innerHTML = `<div class="security-note">${esc(error.message)}</div>`;
}
