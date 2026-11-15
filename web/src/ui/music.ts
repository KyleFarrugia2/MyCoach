/**
 * Calm background music (original ambient loop, public/audio/calm.m4a).
 *
 * Plays quietly while the setting is on, fades in/out, pauses while a workout is in progress (and when the
 * app is in the background), and resumes afterwards. Browsers only allow audio after the user interacts with
 * the page, so playback starts on the first tap.
 */
const TARGET_VOLUME = 0.22;
const FADE_MS = 1600;

let audio: HTMLAudioElement | undefined;
let wanted = false;
let fadeTimer: number | undefined;
let waitingForGesture = false;

function element(): HTMLAudioElement {
  if (!audio) {
    audio = new Audio("./audio/calm.m4a");
    audio.loop = true;
    audio.preload = "auto";
    audio.volume = 0;
    // Dev-only handle for automated checks.
    if (import.meta.env.DEV) (window as unknown as { __mcAudio?: HTMLAudioElement }).__mcAudio = audio;
  }
  return audio;
}

function fadeTo(target: number, then?: () => void) {
  const a = element();
  window.clearInterval(fadeTimer);
  const start = a.volume;
  const t0 = performance.now();
  fadeTimer = window.setInterval(() => {
    const k = Math.min(1, (performance.now() - t0) / FADE_MS);
    a.volume = Math.max(0, Math.min(1, start + (target - start) * k));
    if (k >= 1) {
      window.clearInterval(fadeTimer);
      then?.();
    }
  }, 50);
}

function tryPlay() {
  const a = element();
  a.play()
    .then(() => fadeTo(TARGET_VOLUME))
    .catch(() => {
      // Autoplay blocked until the first interaction.
      if (waitingForGesture) return;
      waitingForGesture = true;
      const resume = () => {
        waitingForGesture = false;
        window.removeEventListener("pointerdown", resume);
        window.removeEventListener("keydown", resume);
        if (wanted && document.visibilityState === "visible") tryPlay();
      };
      window.addEventListener("pointerdown", resume, { once: true });
      window.addEventListener("keydown", resume, { once: true });
    });
}

function apply() {
  const a = element();
  const shouldPlay = wanted && document.visibilityState === "visible";
  if (shouldPlay && (a.paused || a.volume < TARGET_VOLUME)) tryPlay();
  if (!shouldPlay && !a.paused) fadeTo(0, () => a.pause());
}

/** Call whenever the setting or workout state changes. */
export function syncMusic(enabled: boolean, workoutActive: boolean) {
  wanted = enabled && !workoutActive;
  apply();
}

if (typeof document !== "undefined") {
  document.addEventListener("visibilitychange", apply);
}
