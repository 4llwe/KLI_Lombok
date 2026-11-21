import { json, serviceRequest, userFromEvent, clean } from "./lib/supabase.mjs";
export const handler = async (event) => {
  if (event.httpMethod !== "POST") return json(405, { error: "Method not allowed" });
  try {
    const user = await userFromEvent(event);
    if (!user) return json(401, { error: "Sesi tidak valid." });
    const [profile] = await serviceRequest(
      `/rest/v1/profiles?id=eq.${encodeURIComponent(user.id)}&select=active`,
    );
    if (!profile?.active) return json(403, { error: "Akun tidak aktif." });
    const input = JSON.parse(event.body || "{}"),
      attemptId = clean(input.attemptId),
      answers = input.answers || {},
      taskResponses = input.taskResponses || {};
    const attempts = await serviceRequest(
      `/rest/v1/assessment_attempts?id=eq.${encodeURIComponent(attemptId)}&student_id=eq.${user.id}&status=eq.in_progress&select=id,test_id,started_at,assessment_tests(pass_score,review_status,validation_status,duration_minutes)`,
    );
    if (!attempts?.length)
      return json(404, { error: "Sesi tes tidak ditemukan atau sudah selesai." });
    // The server, not the browser's completedSeconds, determines elapsed time.
    // A short grace period accounts for ordinary upload/network delays; it is
    // not suitable as a high-stakes exam policy without further review.
    const startedAt = Date.parse(attempts[0].started_at);
    const durationMinutes = Number(attempts[0].assessment_tests?.duration_minutes);
    const now = Date.now();
    if (!Number.isFinite(startedAt) || !Number.isFinite(durationMinutes) || durationMinutes <= 0 || startedAt > now) {
      return json(409, { error: "Waktu tes tidak valid. Hubungi tim akademik." });
    }
    const elapsedMs = now - startedAt;
    if (elapsedMs > durationMinutes * 60_000 + 120_000) {
      return json(409, { error: "Waktu pengiriman tes telah berakhir." });
    }
    const completedSeconds = Math.floor(elapsedMs / 1000);
    const tasks = await serviceRequest(
      `/rest/v1/assessment_tasks?test_id=eq.${attempts[0].test_id}&published=eq.true&select=id,skill`,
    );
    // Files are uploaded into <student>/<attempt>/<task>-<random>.<extension>.
    // Never use a client-supplied path for another user, attempt, or task.
    for (const task of tasks) {
      const filePath = clean(taskResponses[task.id]?.filePath);
      if (!filePath) continue;
      const prefix = `${user.id}/${attemptId}/${task.id}-`;
      const filename = filePath.startsWith(prefix) ? filePath.slice(prefix.length) : "";
      if (task.skill !== "speaking" || !/^[A-Za-z0-9-]+\.[A-Za-z0-9]+$/.test(filename)) {
        return json(400, { error: "Lokasi rekaman tidak valid." });
      }
    }
    const questions = await serviceRequest(
      `/rest/v1/assessment_questions?test_id=eq.${attempts[0].test_id}&select=id,correct_option,points,assessment_sections(code,title)`,
    );
    let earned = 0,
      max = 0;
    const sectionTotals = {};
    const rows = questions.map((q) => {
      const answer = clean(answers[q.id]),
        correct = answer === q.correct_option,
        points = Number(q.points),
        section = Array.isArray(q.assessment_sections)
          ? q.assessment_sections[0]
          : q.assessment_sections,
        code = section?.code || "objective";
      max += points;
      if (correct) earned += points;
      if (!sectionTotals[code])
        sectionTotals[code] = { code, title: section?.title || "Objective", earned: 0, max: 0 };
      sectionTotals[code].max += points;
      if (correct) sectionTotals[code].earned += points;
      return {
        attempt_id: attemptId,
        question_id: q.id,
        answer,
        correct,
        points_awarded: correct ? points : 0,
      };
    });
    await serviceRequest("/rest/v1/assessment_answers", {
      method: "POST",
      headers: { Prefer: "resolution=merge-duplicates,return=minimal" },
      body: rows,
    });
    const responseRows = tasks
      .map((t) => {
        const r = taskResponses[t.id] || {};
        return {
          attempt_id: attemptId,
          task_id: t.id,
          response_text: clean(r.text) || null,
          file_path: clean(r.filePath) || null,
          status: "pending_review",
        };
      })
      .filter((r) => r.response_text || r.file_path);
    if (responseRows.length)
      await serviceRequest("/rest/v1/assessment_task_responses", {
        method: "POST",
        headers: { Prefer: "resolution=merge-duplicates,return=minimal" },
        body: responseRows,
      });
    const objectiveScore = max ? Math.round((earned / max) * 100) : 0,
      sectionResults = Object.values(sectionTotals).map((s) => ({
        ...s,
        score: s.max ? Math.round((s.earned / s.max) * 100) : 0,
      })),
      pending = tasks.length > 0;
    await serviceRequest(`/rest/v1/assessment_attempts?id=eq.${encodeURIComponent(attemptId)}`, {
      method: "PATCH",
      headers: { Prefer: "return=minimal" },
      body: {
        submitted_at: new Date().toISOString(),
        score: objectiveScore,
        max_score: max,
        section_scores: sectionResults,
        status: pending ? "awaiting_review" : "submitted",
        completed_seconds: completedSeconds,
      },
    });
    const passScore = Number(attempts[0].assessment_tests?.pass_score || 70),
      approved =
        attempts[0].assessment_tests?.review_status === "approved" &&
        attempts[0].assessment_tests?.validation_status === "validated";
    return json(200, {
      objectiveScore,
      earned,
      max,
      sectionScores: sectionResults,
      pendingHumanReview: pending,
      practiceOnly: !approved,
      passed: !pending && approved && objectiveScore >= passScore,
      message: pending
        ? "Jawaban objektif tersimpan; writing/speaking menunggu penilaian akademik."
        : "Tes berhasil dinilai.",
    });
  } catch (error) {
    console.error(error);
    return json(500, { error: "Jawaban belum dapat diproses." });
  }
};
