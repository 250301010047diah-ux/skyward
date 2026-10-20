export function createAudio(sdk) {
  let managed = null;
  let context = null;
  let unlocked = false;
  let drone = [];

  async function unlock() {
    if (unlocked) return;
    try {
      managed ||= await sdk.audio.getContext();
      await managed.unlock();
      context = managed.context;
      unlocked = context.state === "running";
      if (unlocked && drone.length === 0) startDrone();
    } catch {
      unlocked = false;
    }
  }

  function tone(frequency, duration, volume = 0.08, type = "triangle", bend = 1) {
    if (!unlocked || context.state !== "running") return;
    const now = context.currentTime;
    const oscillator = context.createOscillator();
    const gain = context.createGain();
    oscillator.type = type;
    oscillator.frequency.setValueAtTime(frequency, now);
    oscillator.frequency.exponentialRampToValueAtTime(Math.max(40, frequency * bend), now + duration);
    gain.gain.setValueAtTime(volume, now);
    gain.gain.exponentialRampToValueAtTime(0.001, now + duration);
    oscillator.connect(gain).connect(context.destination);
    oscillator.start(now);
    oscillator.stop(now + duration);
  }

  function noise(duration, volume = 0.04) {
    if (!unlocked || context.state !== "running") return;
    const length = Math.max(1, Math.floor(context.sampleRate * duration));
    const buffer = context.createBuffer(1, length, context.sampleRate);
    const channel = buffer.getChannelData(0);
    for (let index = 0; index < length; index += 1) {
      channel[index] = (Math.random() * 2 - 1) * (1 - index / length);
    }
    const source = context.createBufferSource();
    const gain = context.createGain();
    gain.gain.value = volume;
    source.buffer = buffer;
    source.connect(gain).connect(context.destination);
    source.start();
  }

  function startDrone() {
    if (!unlocked || drone.length) return;
    const now = context.currentTime;
    for (const [frequency, volume] of [[73.42, 0.012], [110, 0.009]]) {
      const oscillator = context.createOscillator();
      const gain = context.createGain();
      oscillator.type = "sine";
      oscillator.frequency.value = frequency;
      gain.gain.setValueAtTime(0.001, now);
      gain.gain.linearRampToValueAtTime(volume, now + 1.2);
      oscillator.connect(gain).connect(context.destination);
      oscillator.start();
      drone.push({ oscillator, gain });
    }
  }

  function play(name) {
    if (name === "bow") tone(640, 0.07, 0.045, "triangle", 1.7);
    if (name === "impact") {
      tone(190, 0.09, 0.055, "square", 0.55);
      noise(0.06, 0.025);
    }
    if (name === "defeat") {
      tone(280, 0.18, 0.07, "sawtooth", 0.45);
      noise(0.13, 0.035);
    }
    if (name === "coin") tone(880, 0.09, 0.055, "sine", 1.45);
    if (name === "hurt") {
      tone(110, 0.22, 0.09, "square", 0.55);
      noise(0.12, 0.04);
    }
    if (name === "jump") tone(260, 0.12, 0.04, "triangle", 1.8);
    if (name === "warning") tone(82, 0.7, 0.12, "sawtooth", 0.72);
    if (name === "upgrade") {
      tone(520, 0.13, 0.05, "triangle", 1.35);
      setTimeout(() => tone(780, 0.18, 0.05, "triangle", 1.2), 75);
    }
  }

  async function destroy() {
    for (const entry of drone) {
      try {
        entry.oscillator.stop();
      } catch {
        // Oscillators may already be stopped by the browser audio lifecycle.
      }
    }
    drone = [];
    await managed?.dispose().catch(() => {});
    managed = null;
    context = null;
    unlocked = false;
  }

  return { unlock, play, destroy };
}
