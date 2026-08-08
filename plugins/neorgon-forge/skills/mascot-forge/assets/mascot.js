/**
 * Mascot behaviour: idle reactions that escalate as she is clicked, and spring
 * physics so she has some weight when you poke her.
 *
 * Expected markup — the poke wrapper exists because bob, physics and
 * breathe/sway each need their own transform, and one element can only carry
 * one animation per property:
 *
 *   <div class="mascot" data-mascot>
 *     <div class="mascot-poke">
 *       <div class="mascot-inner">
 *         <img data-frame="idle">
 *         <img class="layer" data-layer="blink">
 *         <img class="layer" data-layer="surprise">
 *         ...
 *
 * Any number of elements may share a data-layer value, so a reaction that comes
 * with detached art — the sweat drop on `exasperated` — shows both at once.
 */

// How long a reaction stays up after the last click.
const HOLD_MS = 1400;
// Silence after which she forgets she was ever clicked.
const RESET_MS = 5000;

// The lowest click count at which each reaction takes over. She reads as amused
// before unimpressed before exasperated — an older sister, not an angry one.
const LADDER = [
  { from: 1, frame: "surprise" },
  { from: 2, frame: "amused" },
  { from: 3, frame: "deadpan" },
  { from: 5, frame: "exasperated" },
];

// Keep going past exasperated and she gives up and changes clothes. Cycling
// back to null returns her to the default outfit. `chibi` is the odd one out:
// a super-deformed redraw rather than a costume, so it sits on its own canvas
// and she visibly shrinks into it. Last in the cycle, as the payoff.
const OUTFITS = ["summer", "bikini", "christmas", "halloween", "yukata", "chibi", null];
const OUTFIT_AT = 10;

// Outfits are alternate base frames, not overlays: only `idle` was drawn for
// each, so expressions are suppressed while one is on. They also load on demand
// rather than shipping five extra images to every visitor.
function outfitUrl(baseSrc, outfit) {
  return baseSrc.replace(/[^/]+(?=@)/, outfit ? `outfit-${outfit}` : "idle");
}

// --- physics ---------------------------------------------------------------
// A click shoves her. The body spring recovers with a little overshoot, and a
// softer trail spring chases the body a beat behind. That lag is the whole
// trick: mass arriving late is what reads as hair and fabric having weight,
// without needing them cut onto real layers.
const BODY = { stiffness: 190, damping: 14 };
const TRAIL = { stiffness: 90, damping: 9 };
// Secondary chest motion. Softer and much less damped than the body, so it
// arrives late and rings on for a beat after she has already settled — the
// standard game trick for making a rigid sprite read as having soft mass.
const BOUNCE = { stiffness: 60, damping: 5 };

// Velocity added per click, tuned so one click peaks the body spring near 1.0
// and the amplitudes below can be read directly as "at full deflection".
// An impulse response peaks at roughly v0/ωd, and ωd here is ~11.9.
const IMPULSE = 21;
// Clicking mid-wobble stacks onto the existing velocity, so a frenzy builds
// up — but only to about twice a single click's deflection. Raising this is the
// one knob that makes her bouncier.
const MAX_VELOCITY = 42;

// Amplitudes at full deflection. Deliberately small: this should register as
// her being a physical object, not as an effect you notice.
const SQUASH = 0.038; // scale
const TILT = 1.0; // degrees
const SHEAR = 1.4; // degrees of skew
// The bounce spring peaks around 0.54 rather than 1.0, since it is chasing a
// decaying target rather than being kicked directly. These are sized for that.
const BOUNCE_SHIFT = 0.9; // percent of sprite height
const BOUNCE_STRETCH = 0.035; // scaleY

// Below this she counts as still, the transform is cleared and the loop stops.
const REST = 0.001;
// Never integrate a step longer than this, or a backgrounded tab returns to a
// huge dt and the spring explodes.
const MAX_STEP = 1 / 30;
// Sub-steps per frame, for stability at these stiffnesses.
const SUBSTEPS = 3;

const reducedMotion =
  typeof matchMedia === "function" && matchMedia("(prefers-reduced-motion: reduce)").matches;

const moving = new Set();
let rafId = null;
let lastTime = 0;

function advance(spring, config, target, dt) {
  const acceleration =
    -config.stiffness * (spring.value - target) - config.damping * spring.velocity;
  spring.velocity += acceleration * dt;
  spring.value += spring.velocity * dt;
}

function atRest(state) {
  for (const spring of [state.body, state.trail, state.bounce]) {
    if (Math.abs(spring.value) >= REST || Math.abs(spring.velocity) >= REST) return false;
  }
  return true;
}

function render(state) {
  const squash = state.body.value * SQUASH;
  const lag = state.trail.value;
  state.poke.style.transform =
    `scale(${(1 + squash).toFixed(4)}, ${(1 - squash).toFixed(4)})` +
    ` rotate(${(lag * TILT).toFixed(3)}deg)` +
    ` skewX(${(-lag * SHEAR).toFixed(3)}deg)`;

  if (state.chest) {
    const bounce = state.bounce.value;
    state.chest.style.transform =
      `translateY(${(bounce * BOUNCE_SHIFT).toFixed(4)}%)` +
      ` scaleY(${(1 + bounce * BOUNCE_STRETCH).toFixed(4)})`;
  }
}

function frame(now) {
  const dt = Math.min((now - lastTime) / 1000, MAX_STEP);
  lastTime = now;

  for (const state of moving) {
    for (let i = 0; i < SUBSTEPS; i += 1) {
      const h = dt / SUBSTEPS;
      advance(state.body, BODY, 0, h);
      // Both secondaries chase the body rather than being driven directly, so
      // they inherit its motion and arrive late.
      advance(state.trail, TRAIL, state.body.value, h);
      advance(state.bounce, BOUNCE, state.body.value, h);
    }

    if (atRest(state)) {
      for (const spring of [state.body, state.trail, state.bounce]) {
        spring.value = spring.velocity = 0;
      }
      state.poke.style.transform = "";
      if (state.chest) state.chest.style.transform = "";
      moving.delete(state);
    } else {
      render(state);
    }
  }

  rafId = moving.size ? requestAnimationFrame(frame) : null;
}

function nudge(state) {
  const clamp = (v) => Math.max(-MAX_VELOCITY, Math.min(MAX_VELOCITY, v));
  state.body.velocity = clamp(state.body.velocity + IMPULSE);
  // A little asymmetry so repeated clicks never wobble identically.
  state.trail.velocity = clamp(state.trail.velocity + (Math.random() - 0.5) * 8);

  moving.add(state);
  if (rafId === null) {
    lastTime = performance.now();
    rafId = requestAnimationFrame(frame);
  }
}

function frameFor(count) {
  let frame = null;
  for (const step of LADDER) {
    if (count >= step.from) frame = step.frame;
  }
  return frame;
}

export function initMascot(root) {
  if (!root || root.dataset.mascotReady) return;
  root.dataset.mascotReady = "true";

  const layers = [...root.querySelectorAll("[data-layer]")];
  const base = root.querySelector("img:not([data-layer]):not([data-bounce])");
  const chest = root.querySelector("[data-bounce]");
  const defaultSrc = base ? base.src : "";
  const state = {
    poke: root.querySelector(".mascot-poke") || root,
    chest,
    body: { value: 0, velocity: 0 },
    trail: { value: 0, velocity: 0 },
    bounce: { value: 0, velocity: 0 },
  };

  let count = 0;
  let outfit = -1;
  let holdTimer = null;
  let resetTimer = null;

  function show(frame) {
    for (const layer of layers) {
      layer.classList.toggle("is-visible", layer.dataset.layer === frame);
    }
    // Suspends the idle blink, so she cannot blink over a reaction.
    root.classList.toggle("is-reacting", Boolean(frame));
  }

  function wear(name) {
    if (!base) return;
    const url = outfitUrl(defaultSrc, name);
    base.src = url;
    // The bounce layer is a copy of whatever is showing, so it has to follow.
    if (chest) chest.src = url;
    root.classList.toggle("has-outfit", Boolean(name));
    // Exposed so CSS can size an outfit whose canvas differs from the default —
    // the chibi is a different shape, not just different clothes.
    if (name) {
      root.dataset.outfit = name;
    } else {
      delete root.dataset.outfit;
    }
    if (name) show(null);
  }

  root.addEventListener("click", () => {
    count += 1;

    if (count >= OUTFIT_AT) {
      outfit = (outfit + 1) % OUTFITS.length;
      wear(OUTFITS[outfit]);
      count = 0;
    } else if (!root.classList.contains("has-outfit")) {
      show(frameFor(count));
    }

    if (!reducedMotion) nudge(state);

    clearTimeout(holdTimer);
    clearTimeout(resetTimer);
    holdTimer = setTimeout(() => show(null), HOLD_MS);
    resetTimer = setTimeout(() => {
      count = 0;
    }, RESET_MS);
  });

  // Direct access, for testing and for linking someone straight to one.
  const wanted = new URLSearchParams(location.search).get("mascot");
  if (wanted && OUTFITS.includes(wanted)) {
    outfit = OUTFITS.indexOf(wanted);
    wear(wanted);
  }
}

export function initAllMascots(scope = document) {
  scope.querySelectorAll("[data-mascot]").forEach(initMascot);
}
