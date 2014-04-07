# `ajax` module

	describe "ajax", ->

		app = require "../../source/app"
		performRequest = require( "../../source/ajax/perform-request" ) app
		uri = require "../../source/uri"
		ajaxFactory = require "../../source/ajax"
		ajax = null
		beforeEach -> ajax = ajaxFactory app, performRequest

## What?

**`ajax`** module provides interface for **same-origin** and
**cross-origin ajax requests**.

## Why?

Many features rely on ajax requests.

E.g. to get audio file size we need to make a `HEAD` request to `cs*.vk.me/*`
where the file is stored.

## How?

#### API

```CoffeeScript
app = require "./app"
performRequest = require( "./ajax/perform-request" ) app
ajax = require( "./ajax" ) app, performRequest

callback = ( response, meta ) -> if meta.status is 200 then alert response

ajax.request
	method: "GET"
	url: "http://example.com/"
	callback: callback
	data: to: "send"
	query: params: "to apply"
	headers: to: "set"
```

None of the options are required.

Supported methods are **`"GET"`**, **`"HEAD"`**, and **`"POST"`**.
There're shortcuts for them:
```CoffeeScript
ajax.get url: "/"
ajax.head url: "/"
ajax.post url: "/"
```
Requests are done using http://visionmedia.github.io/superagent internally.
See `test/unit/ajax/perform-request.litcoffee` for more information.

#### Use extension sandboxed script with elevated permissions.

Injected scripts (which we are testing here) can't make cross-origin requests
so we pass request data to some sort of background script which has enough
permissions. See `source/meta/**/*.js` for the background scripts.

**Note**: here "background script" means any sandboxed extension script, that
may be content script, user script, or background script.

Because some ajax requests need correct cookies and Opera 12
(possibly Firefox too) doesn't pass them when making requests from
background script (it has a different context with a different `document`
and with disabled cookies), we have to split ajax handling:
same-origin requests - in ordinary target window with injected scripts,
cross-origin requests - in background context.

#### Talk with that script via `message` event on `window`.

Injected and background scripts talk to each other via `message` events
triggered on `window` object.  
See:
https://developer.mozilla.org/en-US/docs/Web/API/Window.postMessage

`ajax` module sends a message with request data, background script captures it,
fetches response and passes it back with another message.

## Messages specification

#### Request message
**`ajax.*`** triggers **`message`** event on **`window`** object like so:
**`window.postMessage settings, "*"`**.

The `settings` object is guaranteed to have the following properties:
- **`method`** - `"GET"`, `"HEAD"`, `"POST"` - http request method
- **`url`** - `string` - target URL
- **`data`** - `object` - data to send
- **`query`** - `object` - query params to send
- **`headers`** - `object` - request headers to set
- **`requestOf`** - `string` - you should check that this equals project
name: `return unless message.data.requestOf is app.name`
- **`_requestId`** - `string` - unique request identifier

#### Response message
**Background script** captures request message, processes it and
triggers **`message`** event on **`window`** object like so:
**`window.postMessage settings, "*"`**.

The `settings` object is guaranteed to have the following properties:
- **`method`** - `"GET"`, `"HEAD"`, `"POST"` - http request method
- **`url`** - `string` - target URL
- **`data`** - `object` - sent data
- **`query`** - `object` - explicitly specified in `query` option query params
- **`headers`** - `object` - explicitly specified request headers
- **`response`** - `object` -
[recieved data](http://visionmedia.github.io/superagent/#response-properties)
- **`responseOf`** - `string` - you should check that this equals project
name: `return unless message.data.responseOf is app.name`
- **`_requestId`** - `string` - unique response identifier
equal to `_requestId` specified in request message

## Mimic background script for testing purposes

**`mimicBackgroundListener`** is a little helper which mimics
background script.  
It listens for a message which `ajax` module sends, checks that sent data is
correct and invokes callback if provided.

**Note**: this helper never sends a message back with response.  
It just checks that request is correct and calls provided function
(which then may send a response message if needed).

		mimicBackgroundListener = ( callback, expectedData = {}) ->
			listener = ( message ) ->
				# Remove this listener once message is captured.
				window.removeEventListener "message", listener

				requestData = message.data
				for key, value of expectedData
					requestData.should.have.property key
					requestData[ key ].should.deep.equal value
				requestData.requestOf.should.equal app.name
				callback requestData if callback

			window.addEventListener "message", listener, no

## ajax.request
**`ajax.request`** is the central ajax method like `jQuery.ajax`.

		describe "request", ->

#### It uses `performRequest` for same-origin requests:

			it "should use performRequest for same-origin requests", ( done ) ->
				# Will be called by the ajax module as a callback.
				callback = ( response, requestData ) ->
					response.should.equal "foo"
					requestData.response.text.should.equal "foo"
					requestData.method.should.equal "POST"
					requestData.url.should.equal "/some?same-origin=path"
					done()

				fakePerformRequest = sinon.spy ({ data, source, callback }) ->
					data.should.deep.equal
						method: "POST"
						url: "/some?same-origin=path"
						data: "bar"
						query: {}
						headers: {}
						requestOf: app.name
						# _requestId is generated using lodash.uniqueId
						# which has a separate instance for each "ajax"
						# instance, so ID is guaranteed to be 1.
						_requestId: "#{app.name}1"

					callback
						method: "POST"
						url: "/some?same-origin=path"
						response: text: "foo"

				ajax = ajaxFactory app, fakePerformRequest

				ajax.request
					method: "POST"
					url: "/some?same-origin=path"
					data: "bar"
					callback: callback

			it "should use sane defaults", ->
				# ajax.request()

#### It sends cross-origin request data to background script:

			it "should pass cross-origin request data via 'message' event",
				( done ) ->
					requestData =
						method: "POST"
						url: "http://example.com/"
						data: "bar"

					xhr = sinon.useFakeXMLHttpRequest()
					xhr.onCreate = ( xhr ) ->
						throw Error "Trying to create xhr!"

					# Set up a background listener.
					mimicBackgroundListener ->
						xhr.restore()
						done()
					, requestData

					# Send request to background.
					ajax.request requestData

#### And listens for event with response data:

			it "should capture response and pass it to callback", ( done ) ->
				# Will be called by the ajax module as a callback.
				callback = ( response, requestData ) ->
					response.should.equal "foo"
					requestData.response.text.should.equal "foo"
					requestData.method.should.equal "GET"
					requestData.url.should.equal "http://example.com/"
					done()

				# Set up a background listener.
				mimicBackgroundListener ( requestData ) ->
					delete requestData.requestOf
					requestData.responseOf = app.name
					requestData.response = { text: "foo" }
					window.postMessage requestData, "*"

				# Send request to background and call callback on response.
				ajax.request
					url: "http://example.com/"
					callback: callback

## ajax.get
**`ajax.get`** is an alias for `ajax.request method: "GET"`

		describe "get", ->
			it "should set method to GET", ( done ) ->
				sinon.stub ajax, "request", ({ url, method } = {}) ->
					# Method should be changed.
					method.should.equal "GET"
					url.should.equal "http://example.com/"
					ajax.request.restore()
					done()

				# Send request to background.
				ajax.get
					method: "POST"
					url: "http://example.com/"

## ajax.post
**`ajax.post`** is an alias for `ajax.request method: "POST"`

		describe "post", ->
			it "should set method to post", ( done ) ->
				sinon.stub ajax, "request", ({ url, method } = {}) ->
					# Method should be changed.
					method.should.equal "POST"
					url.should.equal "http://example.com/"
					ajax.request.restore()
					done()

				# Send request to background.
				ajax.post
					method: "GET"
					url: "http://example.com/"

## ajax.head
**`ajax.head`** is an alias for `ajax.request method: "HEAD"`

		describe "head", ->
			it "should set method to HEAD", ( done ) ->
				sinon.stub ajax, "request", ({ url, method } = {}) ->
					# Method should be changed.
					method.should.equal "HEAD"
					url.should.equal "http://example.com/"
					ajax.request.restore()
					done()

				# Send request to background.
				ajax.head
					method: "POST"
					url: "http://example.com/"
