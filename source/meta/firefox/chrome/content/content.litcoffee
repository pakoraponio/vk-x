	app = require "../../../../app"
	handleAjax = require "../../../handle-ajax"
	inject = require "../../../inject"

	processOpenedWindow = ({ doc, win, url }) ->
		return unless /^http(s)?:\/\/([a-z0-9\.]+\.)?vk\.com\//.test url

		win.addEventListener "message", handleAjax, no

		# See: content_script.js:23
		inject "window._ext_ldr_vkopt_loader = true", target: doc, isSource: yes

		# See: background.js:10 and gulpfile.js
		inject "run-in-top.js", target: doc if win is win.top

		inject "run-in-frames.js", target: doc if win isnt win.top

	Components.classes[ "@mozilla.org/observer-service;1" ]
		.getService Components.interfaces.nsIObserverService
		.addObserver observe: ( obj, eventType ) ->
			return unless eventType is "document-element-inserted"
			doc = obj
			return unless doc.location?
			win = doc.defaultView
			url = doc.location.href

			processOpenedWindow doc: doc, win: win, url: url
		, "document-element-inserted", no
