const scenes = [
  { id: "mark", ms: 1800 },
  { id: "name", ms: 2000 },
  { id: "app", ms: 0 },
  { id: "hold", ms: 3400 },
];

const screens = [
  { id: "landing", ms: 4800, back: false, cta: "Create New Lesson" },
  { id: "studio", ms: 11200, back: true, cta: "Fill the brief" },
  { id: "run", ms: 9200, back: true, cta: "Writing…" },
  { id: "ready", ms: 3600, back: true, cta: "View Lesson" },
  { id: "teach", ms: 10200, back: true, cta: "Refresh this topic" },
  { id: "history", ms: 4200, back: true, cta: "Create New Lesson" },
  { id: "signin", ms: 3200, back: true, cta: "Sign in" },
];

const notes = [
  "Hold the three photos. Do not name landforms yet. Ask which one is being attacked, which is storing sediment, which is being managed.",
  "Point at fetch first, then wind. Ask why a storm on a small lake can look fierce but will not cut a wave-cut platform.",
  "Two arrows on the beach face: swash up, backwash down. The thicker arrow wins. That is the whole distinction.",
];

const liveCopy = {
  label: ["Labelling the topic", "GCSE Geography · Coastal landscapes · physical geography cluster."],
  cache: ["Checking SYNTRA cache", "14 verified packages on coastal processes. Reusing ranked sources — skipping a live web pass."],
  web: ["Web research", "Skipped — reused from SYNTRA cache."],
  profile: ["Learner profile", "GCSE · AQA · Geography · exam goal · GCSE depth."],
  prereq: ["Prerequisites", "Gaps: weathering vs erosion, reading a simple OS coastline extract."],
  objectives: ["Learning objectives", "Five measurable outcomes, from fetch to a 6-mark management evaluation."],
  lesson: ["Lesson plan", "Seven timed steps. 60 minutes. Process first, then landforms, then management."],
  slides: ["Slides", "Board-ready sequence with spoken cues for each slide."],
  curriculum: ["Curriculum", "Teachable brief assembled. Saving to Past lessons."],
};

const stage = document.getElementById("stage");
const hint = document.getElementById("hint");
const app = document.getElementById("app");
const backBtn = document.getElementById("back-btn");
const navCta = document.getElementById("nav-cta");
const tiles = [...document.querySelectorAll(".tile")];
const pills = [...document.querySelectorAll("#feature-pills span")];
const dossier = document.getElementById("dossier");
const boardBlock = document.getElementById("board-block");
const subjectBlock = document.getElementById("subject-block");
const boards = [...document.querySelectorAll("#boards button")];
const subjects = [...document.querySelectorAll("#subjects button")];
const topicField = document.getElementById("topic-field");
const topicText = document.getElementById("topic-text");
const pipeline = [...document.querySelectorAll("#pipeline li")];

let timer = 0;
let generation = 0;
let recording = false;

function sleep(ms, gen) {
  return new Promise((resolve) => {
    timer = window.setTimeout(resolve, ms);
  }).then(() => gen === generation);
}

function showScene(id) {
  document.querySelectorAll("[data-scene]").forEach((scene) => {
    scene.classList.toggle("on", scene.dataset.scene === id);
    scene.classList.toggle("off", scene.dataset.scene !== id);
  });
}

function showScreen(id) {
  const meta = screens.find((item) => item.id === id);
  document.querySelectorAll("[data-view]").forEach((view) => {
    view.classList.toggle("on", view.dataset.view === id);
  });
  backBtn.classList.toggle("on", Boolean(meta?.back));
  if (navCta && meta?.cta) navCta.textContent = meta.cta;
}

function resetStudio() {
  dossier.classList.remove("on");
  tiles.forEach((tile) => tile.classList.remove("on", "selected"));
  pills.forEach((pill) => pill.classList.remove("on"));
  boardBlock.classList.remove("open");
  subjectBlock.classList.remove("open");
  boards.forEach((btn) => btn.classList.remove("on"));
  subjects.forEach((btn) => btn.classList.remove("on"));
  topicField.classList.remove("hot");
  topicText.textContent = "";
  document.getElementById("dossier-title").textContent = "Curriculum brief";
  document.getElementById("dossier-chips").innerHTML = "";
  document.getElementById("ready-pill").textContent = "Draft";
  document.getElementById("ready-pill").classList.remove("filled");
  ["d-goal", "d-depth", "d-prior"].forEach((id) => {
    const el = document.getElementById(id);
    el.textContent = "—";
    el.classList.remove("filled");
  });
}

function resetRun() {
  pipeline.forEach((li) => li.classList.remove("active", "done", "skip"));
  document.getElementById("run-sub").textContent = "Labelling the topic, then checking the cache.";
  document.getElementById("live-title").textContent = "Gathering resources";
  document.getElementById("live-body").textContent =
    "Research, profile, prerequisites, and objectives appear here as they land.";
  document.getElementById("live-bar").classList.add("on");
}

function resetTeach() {
  document.querySelectorAll(".slide").forEach((slide, i) => slide.classList.toggle("on", i === 0));
  document.getElementById("slide-count").textContent = "Slide 1 / 3";
  document.getElementById("say-this").textContent = notes[0];
  document.querySelectorAll(".pack-row").forEach((row, i) => row.classList.toggle("on", i === 0));
  document.querySelectorAll(".pack-pane").forEach((pane, i) => pane.classList.toggle("on", i === 0));
}

function fillDossier(title, chips, goal, depth, prior, ready) {
  document.getElementById("dossier-title").textContent = title;
  document.getElementById("dossier-chips").innerHTML = chips.map((label) => `<span>${label}</span>`).join("");
  const fields = { "d-goal": goal, "d-depth": depth, "d-prior": prior };
  Object.entries(fields).forEach(([id, value]) => {
    const el = document.getElementById(id);
    el.textContent = value;
    el.classList.toggle("filled", value !== "—");
  });
  const pill = document.getElementById("ready-pill");
  pill.textContent = ready ? "Ready to teach" : "Draft";
  pill.classList.toggle("filled", ready);
}

async function typeTopic(text, gen) {
  topicField.classList.add("hot");
  topicText.textContent = "";
  for (const letter of text) {
    topicText.textContent += letter;
    if (!(await sleep(42, gen))) return false;
  }
  return true;
}

async function playStudio(gen) {
  resetStudio();
  showScreen("studio");
  if (!(await sleep(240, gen))) return;
  for (const tile of tiles) {
    tile.classList.add("on");
    if (!(await sleep(70, gen))) return;
  }
  if (!(await sleep(260, gen))) return;
  dossier.classList.add("on");
  pills[0].classList.add("on");
  if (!(await sleep(400, gen))) return;
  tiles[2].classList.add("selected");
  fillDossier("Curriculum brief", ["GCSE"], "—", "GCSE", "—", false);
  boardBlock.classList.add("open");
  pills[1].classList.add("on");
  if (!(await sleep(500, gen))) return;
  boards[0].classList.add("on");
  fillDossier("Curriculum brief", ["GCSE", "AQA"], "—", "GCSE", "—", false);
  subjectBlock.classList.add("open");
  pills[2].classList.add("on");
  if (!(await sleep(460, gen))) return;
  subjects[5].classList.add("on");
  fillDossier("Curriculum brief", ["Geography", "GCSE", "AQA"], "—", "GCSE", "—", false);
  pills[3].classList.add("on");
  if (!(await sleep(180, gen))) return;
  if (!(await typeTopic("Coastal landscapes", gen))) return;
  fillDossier(
    "Coastal landscapes",
    ["Geography", "GCSE", "AQA"],
    "Prepare for an exam",
    "GCSE",
    "Waves transfer energy; beaches from photos",
    true,
  );
  pills[4].classList.add("on");
  navCta.textContent = "Write lesson";
}

async function playRun(gen) {
  resetRun();
  showScreen("run");
  const order = ["label", "cache", "web", "profile", "prereq", "objectives", "lesson", "slides", "curriculum"];
  for (const id of order) {
    pipeline.forEach((item) => {
      if (item.classList.contains("active")) {
        item.classList.remove("active");
        item.classList.add(item.dataset.step === "web" ? "skip" : "done");
      }
    });
    const li = pipeline.find((item) => item.dataset.step === id);
    li.classList.add("active");
    const copy = liveCopy[id];
    document.getElementById("live-title").textContent = copy[0];
    document.getElementById("live-body").textContent = copy[1];
    if (id === "cache") {
      document.getElementById("run-sub").textContent =
        "Reused from SYNTRA cache (14 hits) — skipping live web research.";
    }
    if (!(await sleep(id === "web" ? 520 : 860, gen))) return;
  }
  pipeline.forEach((item) => {
    item.classList.remove("active");
    if (!item.classList.contains("skip") && !item.classList.contains("done")) item.classList.add("done");
  });
  document.getElementById("live-bar").classList.remove("on");
}

function setPack(index) {
  document.querySelectorAll(".pack-row").forEach((row, i) => row.classList.toggle("on", i === index));
  document.querySelectorAll(".pack-pane").forEach((pane, i) => pane.classList.toggle("on", i === index));
}

async function playTeach(gen) {
  resetTeach();
  showScreen("teach");
  if (!(await sleep(1600, gen))) return;
  document.querySelectorAll(".slide").forEach((slide, i) => slide.classList.toggle("on", i === 1));
  document.getElementById("slide-count").textContent = "Slide 2 / 3";
  document.getElementById("say-this").textContent = notes[1];
  if (!(await sleep(1800, gen))) return;
  document.querySelectorAll(".slide").forEach((slide, i) => slide.classList.toggle("on", i === 2));
  document.getElementById("slide-count").textContent = "Slide 3 / 3";
  document.getElementById("say-this").textContent = notes[2];
  if (!(await sleep(1800, gen))) return;
  setPack(1);
  if (!(await sleep(2000, gen))) return;
  setPack(2);
  if (!(await sleep(1800, gen))) return;
  setPack(3);
}

async function loop(gen) {
  while (gen === generation) {
    resetStudio();
    resetRun();
    resetTeach();
    app.classList.remove("on");
    showScene("mark");
    if (!(await sleep(scenes[0].ms, gen))) return;
    showScene("name");
    if (!(await sleep(scenes[1].ms, gen))) return;
    showScene("app");
    if (!(await sleep(120, gen))) return;
    app.classList.add("on");
    showScreen("landing");
    if (!(await sleep(screens[0].ms, gen))) return;
    await playStudio(gen);
    if (gen !== generation) return;
    if (!(await sleep(800, gen))) return;
    await playRun(gen);
    if (gen !== generation) return;
    showScreen("ready");
    if (!(await sleep(screens[3].ms, gen))) return;
    await playTeach(gen);
    if (gen !== generation) return;
    showScreen("history");
    if (!(await sleep(screens[5].ms, gen))) return;
    showScreen("signin");
    if (!(await sleep(screens[6].ms, gen))) return;
    app.classList.remove("on");
    showScene("hold");
    if (!(await sleep(scenes[3].ms, gen))) return;
  }
}

function replay() {
  generation += 1;
  window.clearTimeout(timer);
  loop(generation);
}

document.addEventListener("keydown", (event) => {
  if (event.code === "Space") {
    event.preventDefault();
    replay();
  }
  if (event.key === "f" || event.key === "F") {
    if (!document.fullscreenElement) document.documentElement.requestFullscreen();
    else document.exitFullscreen();
  }
  if (event.key === "h" || event.key === "H") {
    recording = !recording;
    document.body.classList.toggle("recording", recording);
  }
  if (event.key === "Escape" && document.fullscreenElement) document.exitFullscreen();
});

stage.addEventListener("click", () => {
  if (!document.fullscreenElement) {
    document.documentElement.requestFullscreen().catch(() => {});
  }
});

loop(generation);

if (hint) {
  window.setTimeout(() => {
    hint.style.opacity = "0";
  }, 3600);
}
