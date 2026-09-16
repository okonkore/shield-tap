// iOS Safari requires AudioContext.resume() to happen in a real DOM gesture.
// Godot receives input after that gesture has crossed into its frame loop, so
// remember every context it creates and resume it here first.
(() => {
	const contexts = [];
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
	const unlock = () => {
		for (const context of contexts) {
			if (context.state !== 'running') context.resume().catch(() => {});
		}
	};
	window.addEventListener('pointerdown', unlock, { capture: true, passive: true });
	window.addEventListener('touchend', unlock, { capture: true, passive: true });
	window.addEventListener('keydown', unlock, { capture: true });
})();
