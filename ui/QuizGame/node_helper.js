const NodeHelper = require("node_helper");

module.exports = NodeHelper.create({
	start: function() {
		console.log("Starting node_helper for: " + this.name);
	},

	socketNotificationReceived: function(notification, payload) {
		if (notification === "GET_GAME_STATE") {
			// Here we will fetch data from the Flask backend
			// For now, we'll just send back a dummy response
			this.sendSocketNotification("GAME_STATE_UPDATED", {
				question: "What is the capital of France?",
				answers: ["Paris", "London", "Berlin", "Madrid"]
			});
		}
	}
});
