import { invoke, getSession, uploadPrivateFile } from "./api.js";
const session = getSession();
if (!session?.access_token) location.href = "login.html";
const esc = (v) =>
  String(v ?? "").replace(
    /[&<>'"]/g,
    (c) =>
      ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", "'": "&#39;", '"': "&quot;" })[
        c
      ],
  );
const testId = new URLSearchParams(location.search).get("testId"),
  intro = document.querySelector("#test-intro"),
  form = document.querySelector("#test-form"),
  result = document.querySelector("#test-result"),
  timer = document.querySelector("#timer");
let attempt,
  questions = [],
  tasks = [],
  seconds = 0,
  totalSeconds = 0,
  clock;
const voiceLang = { English: "en-GB", Japanese: "ja-JP", German: "de-DE" };
function taskHtml(t) {
  const heading = `${esc(t.skill.toUpperCase())}`;
  if (t.skill === "reading")
    return `<fieldset class="portal-panel test-question"><legend>${heading}</legend><div class="reading-stimulus">${esc(t.stimulus)}</div><label>Response<textarea name="task-${esc(t.id)}" rows="6" required></textarea></label></fieldset>`;
  if (t.skill === "listening")
    return `<fieldset class="portal-panel test-question"><legend>${heading}</legend>${t.audioUrl ? `<audio controls preload="metadata" src="${esc(t.audioUrl)}"></audio>` : `<button type="button" class="button button-secondary play-audio" data-id="${esc(t.id)}">Putar audio latihan (maks. 2×)</button>`}<p>${esc(t.prompt)}</p><label>Response<textarea name="task-${esc(t.id)}" rows="5" required></textarea></label></fieldset>`;
  if (t.skill === "writing")
    return `<fieldset class="portal-panel test-question"><legend>${heading}</legend><p>${esc(t.prompt)}</p><p><small>Target ${esc(t.min_words)}–${esc(t.max_words)} kata.</small></p><label>Writing response<textarea name="task-${esc(t.id)}" rows="12" required data-minwords="${esc(t.min_words)}" data-maxwords="${esc(t.max_words)}"></textarea></label></fieldset>`;
  return `<fieldset class="portal-panel test-question"><legend>${heading}</legend><p>${esc(t.prompt)}</p><label>Unggah rekaman audio<input type="file" name="file-${esc(t.id)}" accept="audio/webm,audio/mpeg,audio/mp4,audio/wav" required><small>Maksimal 15 MB.</small></label></fieldset>`;
}
function questionsHtml() {
  let sectionCode = "",
    stimulusId = "";
  return questions
    .map((q, i) => {
      const section = Array.isArray(q.assessment_sections)
          ? q.assessment_sections[0]
          : q.assessment_sections,
        stimulus = Array.isArray(q.assessment_stimuli)
          ? q.assessment_stimuli[0]
          : q.assessment_stimuli;
      let prefix = "";
      if (section?.code && section.code !== sectionCode) {
        sectionCode = section.code;
        stimulusId = "";
        prefix += `<section class="test-section-head"><p class="eyebrow">Section ${esc(section.sort_order)}</p><h2>${esc(section.title)}</h2><p>${esc(section.duration_minutes)} minutes</p></section>`;
      }
      if (stimulus?.id && stimulus.id !== stimulusId) {
        stimulusId = stimulus.id;
        prefix +=
          stimulus.stimulus_type === "listening_script"
            ? `<article class="portal-panel listening-stimulus"><div class="listening-title"><div><p class="eyebrow">Questions ${i + 1}–${i + 10}</p><h3>${esc(stimulus.title)}</h3></div><span class="listening-state" id="state-${esc(stimulus.id)}">Ready</span></div><p><small>Use headphones. The recording plays once and cannot be paused. The transcript is withheld during delivery.</small></p><button type="button" class="button play-stimulus" data-id="${esc(stimulus.id)}">▶ Play this part</button></article>`
            : `<article class="portal-panel reading-stimulus"><h3>${esc(stimulus.title)}</h3><p>${esc(stimulus.content)}</p></article>`;
      }
      return (
        prefix +
        `<fieldset class="portal-panel test-question"><legend>${i + 1}. ${esc(q.prompt)}</legend>${q.options.map((o) => `<label><input type="radio" name="${esc(q.id)}" value="${esc(o)}" required> ${esc(o)}</label>`).join("")}</fieldset>`
      );
    })
    .join("");
}
async function start() {
  try {
    const data = await invoke("start-test", { testId }, true);
    attempt = data.attemptId;
    questions = data.questions;
    tasks = data.tasks || [];
    seconds = data.test.duration_minutes * 60;
    totalSeconds = seconds;
    intro.innerHTML = `<p class="eyebrow">${esc(data.test.language)} · ${esc(data.test.level)}</p><h1>${esc(data.test.title)}</h1><p>${esc(data.test.description)}</p><div class="listening-instructions"><b>Listening instructions:</b> Read the questions first, check your device volume, and play each part only when ready.</div>${data.practiceOnly ? '<div class="security-note"><b>Practice/academic review mode.</b> Hasil tidak boleh dipakai sebagai keputusan level final sebelum tes disetujui dan divalidasi.</div>' : ""}`;
    form.innerHTML =
      questionsHtml() +
      tasks.map(taskHtml).join("") +
      '<button class="button button-lg" type="submit">Kirim seluruh jawaban</button>';
    const plays = {};
    document.querySelectorAll(".play-audio").forEach(
      (b) =>
        (b.onclick = () => {
          const task = tasks.find((t) => t.id === b.dataset.id);
          plays[task.id] = (plays[task.id] || 0) + 1;
          if (plays[task.id] > 2) return;
          const utterance = new SpeechSynthesisUtterance(task.stimulus);
          utterance.lang = voiceLang[data.test.language] || "id-ID";
          speechSynthesis.speak(utterance);
          b.textContent =
            plays[task.id] >= 2
              ? "Batas pemutaran tercapai"
              : `Putar sekali lagi`;
          b.disabled = plays[task.id] >= 2;
        }),
    );
    document.querySelectorAll(".play-stimulus").forEach(
      (b) =>
        (b.onclick = () => {
          const q = questions.find((x) => {
              const s = Array.isArray(x.assessment_stimuli)
                ? x.assessment_stimuli[0]
                : x.assessment_stimuli;
              return s?.id === b.dataset.id;
            }),
            s = Array.isArray(q?.assessment_stimuli)
              ? q.assessment_stimuli[0]
              : q?.assessment_stimuli,
            max = s?.max_plays || 2;
          if (!s?.audio_script) return;
          plays[s.id] = (plays[s.id] || 0) + 1;
          if (plays[s.id] > max) return;
          speechSynthesis.cancel();
          document
            .querySelectorAll(".play-stimulus")
            .forEach((x) => (x.disabled = true));
          const state = document.querySelector(`#state-${CSS.escape(s.id)}`),
            u = new SpeechSynthesisUtterance(s.audio_script),
            profile = s.voice_profile || {};
          u.lang = profile.language || "en-GB";
          u.rate = Number(profile.rate || 0.92);
          u.pitch = Number(profile.pitch || 1);
          const voices = speechSynthesis.getVoices(),
            british =
              voices.find((v) => v.lang === "en-GB") ||
              voices.find((v) => v.lang?.startsWith("en"));
          if (british) u.voice = british;
          u.onstart = () => {
            if (state) state.textContent = "Playing";
            b.textContent = "Playing…";
          };
          u.onend = () => {
            if (state) state.textContent = "Completed";
            b.textContent = "✓ Audio completed";
            document.querySelectorAll(".play-stimulus").forEach((x) => {
              if (!plays[x.dataset.id]) x.disabled = false;
            });
          };
          u.onerror = () => {
            if (state) state.textContent = "Audio unavailable";
            b.textContent = "Audio unavailable";
            document.querySelectorAll(".play-stimulus").forEach((x) => {
              if (!plays[x.dataset.id]) x.disabled = false;
            });
          };
          speechSynthesis.speak(u);
          b.disabled = true;
        }),
    );
    clock = setInterval(() => {
      seconds--;
      timer.textContent = `${Math.floor(seconds / 60)}:${String(seconds % 60).padStart(2, "0")}`;
      if (seconds <= 0) {
        clearInterval(clock);
        form.requestSubmit();
      }
    }, 1000);
  } catch (error) {
    intro.innerHTML = `<div class="security-note">${esc(error.message)}</div>`;
    timer.textContent = "Tidak tersedia";
  }
}
form.onsubmit = async (event) => {
  event.preventDefault();
  for (const area of form.querySelectorAll("textarea[data-minwords]")) {
    const count = area.value.trim().split(/\s+/).filter(Boolean).length;
    if (
      count < Number(area.dataset.minwords) ||
      count > Number(area.dataset.maxwords)
    ) {
      area.focus();
      result.textContent = `Jumlah kata harus ${area.dataset.minwords}–${area.dataset.maxwords}.`;
      return;
    }
  }
  clearInterval(clock);
  const button = form.querySelector("button[type=submit]");
  button.disabled = true;
  result.textContent = "Mengunggah dan menyimpan jawaban…";
  try {
    const raw = new FormData(form),
      answers = {},
      taskResponses = {};
    questions.forEach((q) => (answers[q.id] = raw.get(q.id)));
    for (const t of tasks) {
      if (t.skill === "speaking") {
        const file = raw.get(`file-${t.id}`);
        if (!(file instanceof File) || !file.size || file.size > 15728640)
          throw new Error(
            "Rekaman speaking wajib diunggah dan maksimal 15 MB.",
          );
        const ext = (file.name.split(".").pop() || "webm")
            .replace(/[^a-z0-9]/gi, "")
            .toLowerCase(),
          path = `${session.user.id}/${attempt}/${t.id}-${crypto.randomUUID()}.${ext}`;
        await uploadPrivateFile("assessment-responses", path, file);
        taskResponses[t.id] = { filePath: path };
      } else taskResponses[t.id] = { text: raw.get(`task-${t.id}`) };
    }
    const data = await invoke(
      "submit-test",
      {
        attemptId: attempt,
        answers,
        taskResponses,
        completedSeconds: totalSeconds - seconds,
      },
      true,
    );
    form.hidden = true;
    result.innerHTML = `<article class="verification-card valid"><div class="verification-head"><span>✓</span><div><small>Objective score</small><h2>${esc(data.objectiveScore)}%</h2></div></div><p>${esc(data.message)}</p>${data.sectionScores?.length ? `<div class="section-score-grid">${data.sectionScores.map((s) => `<article><small>${esc(s.title)}</small><strong>${esc(s.score)}%</strong><span>${esc(s.earned)}/${esc(s.max)}</span></article>`).join("")}</div>` : ""}${data.practiceOnly ? "<p><b>Hasil latihan:</b> bukan penetapan level atau sertifikat.</p>" : ""}<a class="button" href="portal.html">Kembali ke portal</a></article>`;
  } catch (error) {
    result.innerHTML = `<div class="security-note">${esc(error.message)}</div>`;
    button.disabled = false;
  }
};
start();
