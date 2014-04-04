**Note**: see tests for API documentation. This file only contains notes
on internal details.

# `ajax` module

	_ = require "lodash"

	ajax = ( app ) ->

## ajax.request

		request = ( options = {}) ->
			# Keep callback private, do not pass it with request settings.
			callback = options.callback ? ->
			delete options.callback if options.callback

			requestId = _.uniqueId app.name

			settings = _.defaults options,
				method: "GET"
				url: ""
				data: {}
				query: {}
				headers: {}
			settings._requestId = requestId
			settings.requestOf = app.name

			listener = ({ data }) ->

**Important**: in order to distinguish requests from responses
(both sent via `message` event) background script must add `_responseId`
property to message data with a value of `_requestId` property like so:
`message.data._responseId = message.data._requestId`.

				return unless data.responseOf is app.name
				return unless data._requestId is requestId

				# Don't listen anymore when the response arrives.
				window.removeEventListener "message", listener

				callback data.response.text, data

			# Listen for response.
			window.addEventListener "message", listener, no

			# Send a request, wait for response.
			window.postMessage settings, "*"

## Shortcut methods

		shortcut = {}

		for method in [ "get", "head", "post" ]
			do ( method ) ->
				shortcut[ method ] = ( options = {}) ->
					options.method = method.toUpperCase()
					request options

## Public interface

		request: request
		get: shortcut.get
		head: shortcut.head
		post: shortcut.post
		
	module.exports = ajax