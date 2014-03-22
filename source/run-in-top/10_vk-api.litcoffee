**Note**: see tests for API documentation. This file only contains notes
on internal details.

# app.vkApi

	app.vkApi = do ->

## Private API

		apiAppInfo =
			id: 4238625
			permissions: [
				"friends"
			]

		apiVersion = "5.16"

		authUrlParams =
			client_id: apiAppInfo.id
			scope: apiAppInfo.permissions.join ","
			redirect_uri: encodeURIComponent "https://oauth.vk.com/blank.html"
			display: "popup"
			v: apiVersion
			response_type: "token"

		authUrl = "https://oauth.vk.com/authorize?" +
			( "#{param}=#{value}" for param, value of authUrlParams ).join "&"

		requestBaseUrl = "https://api.vk.com/method/"

## "Public" API

Although these fields are exposed as public, it is strongly recommended to only
use those without an undersore (`_`).
Private methods are here for testing purposes only (see tests).

		_apiVersion: apiVersion

		_accessToken: null

		_performAuth: ({ callback } = {}) ->
			callback ||= ->
			authFrame = vkCe "iframe",
				src: authUrl
				id: "#{app.name}-auth-frame-#{app.util.uniqueId()}"
				style: "display: none"

			listener = ({ data }) ->
				if data.oauthMessageOf is app.name
					callback data.accessToken

			window.addEventListener "message", listener, no

			document.body.appendChild authFrame

#### app.vkApi.getAccessToken

		getAccessToken: ({ callback, force } = {}) ->
			callback ||= ->
			if @_accessToken and not force
				callback @_accessToken
			else
				context = @
				@_performAuth callback: ( accessToken ) ->
					context._accessToken = accessToken
					callback accessToken

#### app.vkApi.request

		request: ({ method, data, callback } = {}) ->
			if not method or not callback
				throw Error "app.vkApi.requests - not enough arguments!"
			else
				data ?= {}
				requestUrl = requestBaseUrl + method
				callbackWrap = ( response, meta ) ->
					callback JSON.parse response
				@getAccessToken callback: ( accessToken ) ->
					data.access_token = accessToken
					data.v ?= apiVersion
					app.ajax.get
						url: requestUrl
						data: data
						callback: callbackWrap