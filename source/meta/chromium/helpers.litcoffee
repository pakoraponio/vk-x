	# This function provides old interface for cross-origin ajax
	# until new one won't be implemented.
	# See: vk_ext_api object defined in vk_lib.js and ./inject.litcoffee
	makeAjaxRequest = ( callback ) -> ({ data }) ->
		return unless data.mark is "vkopt_loader" and data._sub
		
		method = data.act.toUpperCase()
		return unless method in [ "GET", "POST", "HEAD" ]

		requestMetaInfo = data._sub
		url = data.url

		request = new XMLHttpRequest
		request.open method, url, yes
		request.onload = ->
			return unless 200 <= @status < 400
			callback
				sub: requestMetaInfo
				# That's not a typo! That's how VkOpt works.
				response: response:
					if method is "HEAD"
						@getAllResponseHeaders()
					else
						@response
		request.send()

	# http://stackoverflow.com/a/9517879
	inject = ( script, { isSource } = {}) ->
		tag = document.createElement "script"
		if isSource
			tag.textContent = script
		else
			tag.src = chrome.extension.getURL script
		( document.head ? document.documentElement ).appendChild tag