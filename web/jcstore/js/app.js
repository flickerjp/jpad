const catalogEl = document.getElementById("catalog");
const midiStatusEl = document.getElementById("midi-status");

/** @type {MIDIAccess | null} */
let midiAccess = null;
/** @type {MIDIOutput | null} */
let midiOut = null;
const activeNotes = new Map();

initMidi();
loadCatalog();

async function initMidi() {
  if (!navigator.requestMIDIAccess) {
    setMidiStatus("Web MIDI not supported in this browser.", "warn");
    return;
  }
  try {
    midiAccess = await navigator.requestMIDIAccess({ sysex: false });
    pickDefaultOutput();
    midiAccess.onstatechange = () => pickDefaultOutput();
    if (!midiOut) {
      setMidiStatus("No MIDI output — connect a synth or use Chrome.", "warn");
    }
  } catch (err) {
    setMidiStatus(`MIDI blocked: ${err.message}`, "warn");
  }
}

function pickDefaultOutput() {
  if (!midiAccess) return;
  const outputs = [...midiAccess.outputs.values()];
  midiOut = outputs[0] ?? null;
  if (midiOut) {
    setMidiStatus(`MIDI out: ${midiOut.name}`, "ok");
  }
}

function setMidiStatus(text, kind = "") {
  midiStatusEl.textContent = text;
  midiStatusEl.className = `midi-status ${kind}`.trim();
}

async function loadCatalog() {
  try {
    const manifestRes = await fetch("manifest.json");
    if (!manifestRes.ok) throw new Error(`manifest ${manifestRes.status}`);
    const manifest = await manifestRes.json();
    const base = resolveBase(manifest);

    catalogEl.innerHTML = "";
    for (const entry of manifest.presets ?? []) {
      const card = document.createElement("details");
      card.className = "preset-card";
      const published = entry.publishedAt
        ? `<span class="preset-date">${escapeHtml(entry.publishedAt)}</span>`
        : "";
      card.innerHTML = `
        <summary>
          <h2 class="preset-title">${escapeHtml(entry.title)}</h2>
          <span class="preset-id">${escapeHtml(entry.id)}</span>
          ${published}
          <p class="preset-desc">${escapeHtml(entry.description ?? "")}</p>
        </summary>
        <div class="preset-body">
          <p class="loading">Loading pads…</p>
        </div>
      `;
      const body = card.querySelector(".preset-body");
      catalogEl.appendChild(card);

      card.addEventListener("toggle", async () => {
        if (!card.open || body.dataset.loaded) return;
        try {
          const url = new URL(entry.path, base).href;
          const presetRes = await fetch(url);
          if (!presetRes.ok) throw new Error(`preset ${presetRes.status}`);
          const preset = await presetRes.json();
          body.replaceChildren(renderPadGrid(preset));
          body.dataset.loaded = "1";
        } catch (err) {
          body.innerHTML = `<p class="error">Failed to load preset: ${escapeHtml(err.message)}</p>`;
        }
      });
    }
  } catch (err) {
    catalogEl.innerHTML = `<p class="error">Could not load catalog: ${escapeHtml(err.message)}</p>`;
  }
}

function resolveBase(manifest) {
  if (manifest.baseURL) return manifest.baseURL;
  return new URL("./", window.location.href).href;
}

/**
 * @param {object} preset
 */
function renderPadGrid(preset) {
  const frag = document.createDocumentFragment();
  const grid = document.createElement("div");
  grid.className = "pad-grid";
  const channel = Math.max(0, (preset.defaultChannel ?? 1) - 1);
  const velocity = preset.defaultVelocity ?? 100;

  for (const pad of preset.pads ?? []) {
    const btn = document.createElement("button");
    btn.type = "button";
    btn.className = "pad-btn";
    btn.innerHTML = `<span class="pad-root">${escapeHtml(pad.displayName ?? pad.name ?? "?")}</span>${escapeHtml(pad.label ?? pad.role ?? "")}`;
    btn.addEventListener("pointerdown", (e) => {
      e.preventDefault();
      playPad(pad, channel, velocity, btn);
    });
    grid.appendChild(btn);
  }

  const hint = document.createElement("p");
  hint.className = "pad-hint";
  hint.textContent = midiOut
    ? "Tap a pad to preview bass + chord via Web MIDI."
    : "Tap pads (no MIDI output — audio preview only in app).";

  frag.appendChild(grid);
  frag.appendChild(hint);
  return frag;
}

function playPad(pad, channel, velocity, btn) {
  const notes = [...(pad.bassNotes ?? []), ...(pad.chordNotes ?? [])];
  if (!notes.length) return;

  btn.classList.add("playing");
  if (midiOut) {
    for (const note of notes) {
      midiOut.send([0x90 + channel, note, velocity]);
    }
    const key = btn;
    const prev = activeNotes.get(key);
    if (prev) clearTimeout(prev.timer);
    const timer = window.setTimeout(() => {
      for (const note of notes) {
        midiOut.send([0x80 + channel, note, 0]);
      }
      btn.classList.remove("playing");
      activeNotes.delete(key);
    }, 420);
    activeNotes.set(key, { timer, notes, channel });
  } else {
    window.setTimeout(() => btn.classList.remove("playing"), 180);
  }
}

function escapeHtml(str) {
  return String(str)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}
