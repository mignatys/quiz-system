/* global Module */

/* MagicMirror²
 * Module: QuizGame
 *
 * By Michael Teeuw https://michaelteeuw.nl
 * MIT Licensed.
 */
Module.register("QuizGame", {
	// Default module config.
	defaults: {
		text: "Hello World!"
	},

	// Override dom generator.
	getDom: function () {
		var wrapper = document.createElement("div");
		wrapper.innerHTML = this.config.text;
		return wrapper;
	}
});
