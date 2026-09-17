// iOS Safari requires AudioContext.resume() to happen in a real DOM gesture.
// Godot receives input after that gesture has crossed into its frame loop, so
// remember every context it creates and resume it here first. Game effects are
// played through this native context as well; AudioStreamGenerator is unreliable
// on some iOS Safari versions.
(() => {
	const contexts = [];
	const NativeAudioContext = window.AudioContext || window.webkitAudioContext;
	let gameContext = null;
	let confirmed = false;
	const guardSound = new Audio('shield-tap-guard-pan-v1.mp3');
	guardSound.preload = 'auto';
	guardSound.volume = 0.72;
	const wrap = (NativeAudioContext) => {
		if (!NativeAudioContext) return NativeAudioContext;
		function GestureAudioContext(...args) {
			const context = new NativeAudioContext(...args);
			contexts.push(context);
			return context;
		}
		GestureAudioContext.prototype = NativeAudioContext.prototype;
		Object.setPrototypeOf(GestureAudioContext, NativeAudioContext);
		return GestureAudioContext;
	};

	window.AudioContext = wrap(window.AudioContext);
	window.webkitAudioContext = wrap(window.webkitAudioContext);
	const getGameContext = () => {
		if (!gameContext && NativeAudioContext) gameContext = new NativeAudioContext();
		return gameContext;
	};
	const play = (frequency, duration, noise, drop) => {
		const context = getGameContext();
		if (!context) return;
		if (context.state !== 'running') context.resume().catch(() => {});
		const now = context.currentTime;
		const oscillator = context.createOscillator();
		const gain = context.createGain();
		oscillator.type = noise > 0.25 ? 'square' : 'triangle';
		oscillator.frequency.setValueAtTime(Math.max(45, frequency), now);
		oscillator.frequency.exponentialRampToValueAtTime(Math.max(38, frequency * (1 + drop)), now + duration);
		gain.gain.setValueAtTime(0.0001, now);
		gain.gain.exponentialRampToValueAtTime(0.12, now + 0.008);
		gain.gain.exponentialRampToValueAtTime(0.0001, now + duration);
		oscillator.connect(gain).connect(context.destination);
		oscillator.start(now);
		oscillator.stop(now + duration + 0.02);
	};
	const playGuard = () => {
		// A fresh element permits rapid consecutive blocks without cutting off the prior clang.
		const sound = guardSound.cloneNode();
		sound.volume = 0.72;
		sound.play().catch(() => play(210, 0.16, 0.13, -0.12));
	};
	window.shieldTapAudio = { play, playGuard };
	const unlock = () => {
		for (const context of contexts) {
			if (context.state !== 'running') context.resume().catch(() => {});
		}
		const context = getGameContext();
		if (context && context.state !== 'running') context.resume().catch(() => {});
		if (!confirmed) {
			confirmed = true;
			play(620, 0.07, 0.0, -0.05);
		}
	};
	window.addEventListener('pointerdown', unlock, { capture: true, passive: true });
	window.addEventListener('touchend', unlock, { capture: true, passive: true });
	window.addEventListener('keydown', unlock, { capture: true });
})();
