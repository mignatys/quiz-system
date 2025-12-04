/* global Module */

/* Magic Mirror
 * Module: QuizGame
 *
 * By Michael Teeuw http://michaelteeuw.nl
 * MIT Licensed.
 */

Module.register("QuizGame", {
	// Default module config.
	defaults: {
		text: "Welcome to the quiz game!"
	},

	// Override dom generator.
	getDom: function () {
		var wrapper = document.createElement("div");
		wrapper.innerHTML = this.config.text;
		return wrapper;
	}
});
