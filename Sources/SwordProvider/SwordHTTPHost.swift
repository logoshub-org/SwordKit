// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (C) 2026 Logos Hub Ltd

import Foundation
import CSwordCore

/// The host's side of SWORD's downloads (plan D134, D137): SWORD asks for a URL through the C layer, and this fetches it with
/// `URLSession`, so the TLS is the system's. SWORD's own codes come back: 0 success, -1 cancelled, -2 timed out, -3 access denied,
/// -5 an HTTP error status, -10 anything else.
public enum SwordHTTPHost {

	/// Registers the fetch function for the whole process.
	public static func register() {
		swx_set_http_fetch(fetch, nil)
	}

	package static func unregister() {
		swx_set_http_fetch(nil, nil)
	}

	// Answers the server-trust and login challenges: the system judges the certificate (one it rejects is still taken when SWORD
	// allows unverified peers), and the user and password SWORD was given are offered to a server that asks.
	private final class Challenges: NSObject, URLSessionDelegate {
		package var allowUnverified = false
		package var user = ""
		package var password = ""

		package func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge,
		                completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
			let method = challenge.protectionSpace.authenticationMethod
			if method == NSURLAuthenticationMethodServerTrust, let trust = challenge.protectionSpace.serverTrust {
				if !SecTrustEvaluateWithError(trust, nil), allowUnverified {
					completionHandler(.useCredential, URLCredential(trust: trust))
				} else {
					completionHandler(.performDefaultHandling, nil)
				}
			} else if (method == NSURLAuthenticationMethodHTTPBasic || method == NSURLAuthenticationMethodHTTPDigest),
			          !user.isEmpty, challenge.previousFailureCount == 0 {
				completionHandler(.useCredential, URLCredential(user: user, password: password, persistence: .none))
			} else {
				completionHandler(.performDefaultHandling, nil)
			}
		}
	}

	private static let fetch: swx_http_fetch = { _, request, hooks, body, length in
		guard let request, let hooks, let body, let length,
		      let url = URL(string: String(cString: request.pointee.url)) else { return -10 }
		var urlRequest = URLRequest(url: url)
		if request.pointee.timeout_ms > 0 { urlRequest.timeoutInterval = Double(request.pointee.timeout_ms) / 1000 }
		let challenges = Challenges()
		challenges.allowUnverified = request.pointee.allow_unverified != 0
		challenges.user = String(cString: request.pointee.user)
		challenges.password = String(cString: request.pointee.password)
		let session = URLSession(configuration: .ephemeral, delegate: challenges, delegateQueue: nil)
		defer { session.finishTasksAndInvalidate() }

		let done = DispatchSemaphore(value: 0)
		var received: Data?
		var status = 0
		var failure: URLError?
		let task = session.dataTask(with: urlRequest) { data, response, error in
			if let error { failure = error as? URLError ?? URLError(.unknown) }
			else {
				received = data
				status = (response as? HTTPURLResponse)?.statusCode ?? 0
			}
			done.signal()
		}
		task.resume()

		// report progress and honour a cancel while the download runs
		var cancelled = false
		while done.wait(timeout: .now() + .milliseconds(100)) == .timedOut {
			if !cancelled, let asked = hooks.pointee.cancelled, asked(hooks.pointee.transport) != 0 {
				task.cancel()
				cancelled = true
			}
			let expected = max(task.countOfBytesExpectedToReceive, 0)
			let now = max(task.countOfBytesReceived, 0)
			hooks.pointee.progress?(hooks.pointee.transport, UInt(max(expected, now)), UInt(now))
		}

		if let failure {
			if cancelled { return -1 }
			switch failure.code {
			case .timedOut: return -2
			case .userAuthenticationRequired, .noPermissionsToReadFile: return -3
			default: return -10
			}
		}
		if status >= 400 { return -5 }
		let data = received ?? Data()
		let buffer = malloc(max(data.count, 1))!.assumingMemoryBound(to: UInt8.self)
		data.copyBytes(to: buffer, count: data.count)
		body.pointee = buffer
		length.pointee = UInt(data.count)
		hooks.pointee.progress?(hooks.pointee.transport, UInt(data.count), UInt(data.count))
		return 0
	}
}
