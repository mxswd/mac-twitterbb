//
//  TwitterService.swift
//  TwitterBB
//
//  Created by Maxwell on 28/06/21.
//

import Foundation
import Combine
import CommonCrypto
import NaturalLanguage
import AuthenticationServices

let TWITTER_CONSUMER_KEY = "asdf"
let TWITTER_CONSUMER_SECRET = "asdf"
let TWITTER_URL_SCHEME = "mactwitterbb"

extension Notification.Name {
    static let twitterCallback = Notification.Name(rawValue: "Twitter.CallbackNotification.Name")
}

@objc class TwitterService: NSObject, ObservableObject {
    @objc var viewController: ViewController?
    @objc var context: ASWebAuthenticationPresentationContextProviding?
    
  let objectWillChange = PassthroughSubject<TwitterService,Never>()
  
  @Published var authUrl: URL? {
    willSet { self.objectWillChange.send(self) }
  }
  
  @Published var showSheet: Bool = false {
    willSet { self.objectWillChange.send(self) }
  }
  
  var callbackObserver: Any? {
    willSet {
      // we will add and remove this observer on an as-needed basis
      guard let token = callbackObserver else { return }
      NotificationCenter.default.removeObserver(token)
    }
  }
  
    func authorizationHeader(params: [String: Any]) -> String {
      var parts: [String] = []
      for param in params {
        let key = param.key.urlEncoded
        let val = "\(param.value)".urlEncoded
        parts.append("\(key)=\"\(val)\"")
      }
      return "OAuth " + parts.sorted().joined(separator: ", ")
    }


    func loadContent(_ data: Data) {
        var xs: [Tweet] = []
        var topicTags: Set<String> = []
        if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? Array<NSDictionary> {
            self.viewController?.setTweetData(json)
            if false {
                json.forEach { (dict: NSDictionary) in
                    var stringTags: Set<String> = []
                    let id = dict["id"] as! NSNumber
                    let text = dict["text"] as! String
                    let name = (dict["user"] as! NSDictionary)["name"] as! String
                    let profile = (dict["user"] as! NSDictionary)["profile_image_url"] as! String
                    let time = dict["created_at"] as! String
                    let tags: [NLTag] = [.personalName, .placeName, .organizationName]
                    let tagger = NLTagger(tagSchemes: [.nameType])
                    tagger.string = text
                    let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace, .joinNames]
                    tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType, options: options) { tag, tokenRange in
                        if let tag = tag, tags.contains(tag) {
                            print("\(text[tokenRange]): \(tag.rawValue)")
                            let (hypotheses, _) = tagger.tagHypotheses(at: tokenRange.lowerBound, unit: .word, scheme: .nameType, maximumCount: 1)
                            print(hypotheses)
                            let str = String(text[tokenRange])
                            topicTags.insert(str)
                            stringTags.insert(str)
                        }
                        return true
                    }
                    xs.append(Tweet(id: id, body: text, name: name, profile: profile, time: time, stringTags: stringTags))
                }
            }
        }
        
        var topic: [String: [Tweet]] = [:]
        var noTopic: [String: [Tweet]] = [:]
        
        xs.forEach { tweet in
            var hasNoTopic = true
            for tag in topicTags {
                if tweet.stringTags.contains(tag) {
                    hasNoTopic = false
                    if let ts = topic[tag] {
                        var z = ts
                        z.append(tweet)
                        topic[tag] = z
                    } else {
                        topic[tag] = [tweet]
                    }
                    break
                }
            }
            
            if hasNoTopic {
                if let ts = noTopic[tweet.name] {
                    var z = ts
                    z.append(tweet)
                    noTopic[tweet.name] = z
                } else {
                    noTopic[tweet.name] = [tweet]
                }
            }
        }
        
        var ts: [Topic] = []
        topic.forEach { title, values in
            ts.append(Topic(title: title, id: values.first!.id, tweets: values))
        }
        noTopic.forEach { title, values in
            // group by author
            ts.append(Topic(title: title, id: values.first!.id, tweets: values))
        }
        self.topics = ts
    }
    
    func signatureKey(_ consumerSecret: String,_ oauthTokenSecret: String?) -> String {
      
        guard let oauthSecret = oauthTokenSecret?.urlEncoded
              else { return consumerSecret.urlEncoded+"&" }
      
        return consumerSecret.urlEncoded+"&"+oauthSecret
      
    }

    func signatureParameterString(params: [String: Any]) -> String {
      var result: [String] = []
      for param in params {
        let key = param.key.urlEncoded
        let val = "\(param.value)".urlEncoded
        result.append("\(key)=\(val)")
      }
      return result.sorted().joined(separator: "&")
    }

    func hmac_sha1(signingKey: String, signatureBase: String) -> String {
      // HMAC-SHA1 hashing algorithm returned as a base64 encoded string
      var digest = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
      CCHmac(CCHmacAlgorithm(kCCHmacAlgSHA1), signingKey, signingKey.count, signatureBase, signatureBase.count, &digest)
      let data = Data(digest)
      return data.base64EncodedString()
    }
    
    func signatureBaseString(_ httpMethod: String = "POST",_ url: String,
                             _ params: [String:Any], _ urlParams: [String: Any] = [:]) -> String {
      
        let parameterString = signatureParameterString(params: params.merging(urlParams, uniquingKeysWith: { a, b in
            return a
        }))
      return httpMethod + "&" + url.urlEncoded + "&" + parameterString.urlEncoded
      
    }
    
    func oauthSignature(httpMethod: String = "POST", url: String,
                        params: [String: Any], urlParams: [String: Any] = [:], consumerSecret: String,
                        oauthTokenSecret: String? = nil) -> String {
      
      let signingKey = signatureKey(consumerSecret, oauthTokenSecret)
      let signatureBase = signatureBaseString(httpMethod, url, params, urlParams)
      return hmac_sha1(signingKey: signingKey, signatureBase: signatureBase)
      
    }

    struct RequestOAuthTokenInput {
      let consumerKey: String
      let consumerSecret: String
      let callbackScheme: String
    }
    struct RequestOAuthTokenResponse {
      let oauthToken: String
      let oauthTokenSecret: String
      let oauthCallbackConfirmed: String
    }
    
    func requestOAuthToken(args: RequestOAuthTokenInput,_ complete: @escaping (RequestOAuthTokenResponse) -> Void) {
      
      let request = (url: "https://api.twitter.com/oauth/request_token", httpMethod: "POST")
      let callback = args.callbackScheme + "://success"
      
      var params: [String: Any] = [
        "oauth_callback" : callback,
        "oauth_consumer_key" : args.consumerKey,
        "oauth_nonce" : UUID().uuidString, // nonce can be any 32-bit string made up of random ASCII values
        "oauth_signature_method" : "HMAC-SHA1",
        "oauth_timestamp" : String(Int(NSDate().timeIntervalSince1970)),
        "oauth_version" : "1.0"
      ]
      // Build the OAuth Signature from Parameters
      params["oauth_signature"] = oauthSignature(httpMethod: request.httpMethod, url: request.url,
                                                 params: params, consumerSecret: args.consumerSecret)
      
      // Once OAuth Signature is included in our parameters, build the authorization header
      let authHeader = authorizationHeader(params: params)
      
      guard let url = URL(string: request.url) else { return }
      var urlRequest = URLRequest(url: url)
      urlRequest.httpMethod = request.httpMethod
      urlRequest.setValue(authHeader, forHTTPHeaderField: "Authorization")
      let task = URLSession.shared.dataTask(with: urlRequest) { (data, response, error) in
        guard let data = data else { return }
        guard let dataString = String(data: data, encoding: .utf8) else { return }
        // dataString should return: oauth_token=XXXX&oauth_token_secret=YYYY&oauth_callback_confirmed=true
        let attributes = dataString.urlQueryStringParameters
        let result = RequestOAuthTokenResponse(oauthToken: attributes["oauth_token"] ?? "",
                                               oauthTokenSecret: attributes["oauth_token_secret"] ?? "",
                                               oauthCallbackConfirmed: attributes["oauth_callback_confirmed"] ?? "")
        complete(result)
      }
      task.resume()
    }

    struct RequestAccessTokenInput {
      let consumerKey: String
      let consumerSecret: String
      let requestToken: String // = RequestOAuthTokenResponse.oauthToken
      let requestTokenSecret: String // = RequestOAuthTokenResponse.oauthTokenSecret
      let oauthVerifier: String
    }
    struct RequestAccessTokenResponse {
      let accessToken: String
      let accessTokenSecret: String
      let userId: String
      let screenName: String
    }
    func requestAccessToken(args: RequestAccessTokenInput,
                            _ complete: @escaping (RequestAccessTokenResponse) -> Void) {
      
      let request = (url: "https://api.twitter.com/oauth/access_token", httpMethod: "POST")
      
      var params: [String: Any] = [
        "oauth_token" : args.requestToken,
        "oauth_verifier" : args.oauthVerifier,
        "oauth_consumer_key" : args.consumerKey,
        "oauth_nonce" : UUID().uuidString, // nonce can be any 32-bit string made up of random ASCII values
        "oauth_signature_method" : "HMAC-SHA1",
        "oauth_timestamp" : String(Int(NSDate().timeIntervalSince1970)),
        "oauth_version" : "1.0"
      ]
      
      // Build the OAuth Signature from Parameters
      params["oauth_signature"] = oauthSignature(httpMethod: request.httpMethod, url: request.url,
                                                 params: params, consumerSecret: args.consumerSecret,
                                                 oauthTokenSecret: args.requestTokenSecret)
      
      // Once OAuth Signature is included in our parameters, build the authorization header
      let authHeader = authorizationHeader(params: params)
      
      guard let url = URL(string: request.url) else { return }
      var urlRequest = URLRequest(url: url)
      urlRequest.httpMethod = request.httpMethod
      urlRequest.setValue(authHeader, forHTTPHeaderField: "Authorization")
      let task = URLSession.shared.dataTask(with: urlRequest) { (data, response, error) in
        guard let data = data else { return }
        guard let dataString = String(data: data, encoding: .utf8) else { return }
        let attributes = dataString.urlQueryStringParameters
        let result = RequestAccessTokenResponse(accessToken: attributes["oauth_token"] ?? "",
                                                accessTokenSecret: attributes["oauth_token_secret"] ?? "",
                                                userId: attributes["user_id"] ?? "",
                                                screenName: attributes["screen_name"] ?? "")
        complete(result)
      }
      task.resume()
    }

    @Published var credential: RequestAccessTokenResponse? {
      willSet { self.objectWillChange.send(self) }
    }
    
    struct Topic : Identifiable, Hashable {
        var title: String
        var id: NSNumber
        
        var tweets: [Tweet]
    }
    
    struct Tweet : Identifiable, Hashable {
        var id: NSNumber
        
        var body: String
        var name: String
        var profile: String
        var time: String
        
        var stringTags: Set<String>
        
        var image: NSImage {
            return NSImage(named: "multiply.circle.fill")!
        }
    }
    
    @Published var topics: [Topic]? {
        willSet { self.objectWillChange.send(self) }
    }
    
    func getTweets() {
        
        let timelineURL = URL(string: "https://api.twitter.com/1.1/statuses/home_timeline.json?count=200")!
        var urlRequest = URLRequest(url: timelineURL)
        urlRequest.httpMethod = "GET"
        var params: [String: Any] = [
            "oauth_consumer_key" : TWITTER_CONSUMER_KEY,
          "oauth_nonce" : UUID().uuidString, // nonce can be any 32-bit string made up of random ASCII values
          "oauth_signature_method" : "HMAC-SHA1",
          "oauth_timestamp" : String(Int(NSDate().timeIntervalSince1970)),
            "oauth_token": self.credential!.accessToken,
          "oauth_version" : "1.0"
        ]
        // Build the OAuth Signature from Parameters
        params["oauth_signature"] = self.oauthSignature(httpMethod: "GET", url: "https://api.twitter.com/1.1/statuses/home_timeline.json",
                                                        params: params, urlParams: ["count":"200"], consumerSecret: TWITTER_CONSUMER_SECRET, oauthTokenSecret: self.credential!.accessTokenSecret)
        
        let authHeader = self.authorizationHeader(params: params)
        urlRequest.setValue(authHeader, forHTTPHeaderField: "Authorization")
        
        // Once OAuth Signature is included in our parameters, build the authorization header
//                let urlParams = self.signatureParameterString(params: params)
//                let finalURL = timelineURL.absoluteString.appending("?").appending(urlParams)
//                urlRequest.url = URL(string: finalURL)
        
        let task = URLSession.shared.dataTask(with: urlRequest) { (data, response, error) in
          guard let data = data else { return }
            DispatchQueue.main.async {
                self.loadContent(data)
            }
        }
        task.resume()
    }

    @objc func authorize() {
      self.showSheet = true // opens the sheet containing our safari view
      
      // Start Step 1: Requesting an access token
      let oAuthTokenInput = RequestOAuthTokenInput(consumerKey: TWITTER_CONSUMER_KEY,
                                                   consumerSecret: TWITTER_CONSUMER_SECRET,
                                                   callbackScheme: TWITTER_URL_SCHEME)
      requestOAuthToken(args: oAuthTokenInput) { oAuthTokenResponse in
        // Kick off our Step 2 observer: start listening for user login callback in scene delegate (from handleOpenUrl)
        self.callbackObserver = NotificationCenter.default.addObserver(forName: .twitterCallback, object: nil, queue: .main) { notification in
          self.callbackObserver = nil // remove notification observer
          self.showSheet = false      // hide sheet containing safari view
          self.authUrl = nil          // remove safari view
          guard let url = notification.object as? URL else { return }
          guard let parameters = url.query?.urlQueryStringParameters else { return }
          /*
          url => twittersdk://success?oauth_token=XXXX&oauth_verifier=ZZZZ
          url.query => oauth_token=XXXX&oauth_verifier=ZZZZ
          url.query?.urlQueryStringParameters => ["oauth_token": "XXXX", "oauth_verifier": "YYYY"]
          */
          guard let verifier = parameters["oauth_verifier"] else { return }
          // Start Step 3: Request Access Token
          let accessTokenInput = RequestAccessTokenInput(consumerKey: TWITTER_CONSUMER_KEY,
                                                         consumerSecret: TWITTER_CONSUMER_SECRET,
                                                         requestToken: oAuthTokenResponse.oauthToken,
                                                         requestTokenSecret: oAuthTokenResponse.oauthTokenSecret,
                                                         oauthVerifier: verifier)
          self.requestAccessToken(args: accessTokenInput) { accessTokenResponse in
            // Process Completed Successfully!
            DispatchQueue.main.async {
              self.credential = accessTokenResponse
              self.authUrl = nil
                self.getTweets()
            }
          }
        }
                                                
        // Start Step 2: User Twitter Login
        let urlString = "https://api.twitter.com/oauth/authorize?oauth_token=\(oAuthTokenResponse.oauthToken)"
        guard let oauthUrl = URL(string: urlString) else { return }
        DispatchQueue.main.async {
          self.authUrl = oauthUrl // sets our safari view url
            let auth = ASWebAuthenticationSession(url: self.authUrl!, callbackURLScheme: "mactwitterbb") { callbackURL, err in
                if let c = callbackURL {
                    self.gotAuth(oAuthTokenResponse, c)
                }
            }
            auth.presentationContextProvider = self.context
            auth.start()
        }
      }
    }

    
    func gotAuth(_ oAuthTokenResponse: RequestOAuthTokenResponse, _ url: URL) {
        self.callbackObserver = nil // remove notification observer
        self.showSheet = false      // hide sheet containing safari view
        self.authUrl = nil          // remove safari view
        guard let parameters = url.query?.urlQueryStringParameters else { return }
        /*
        url => twittersdk://success?oauth_token=XXXX&oauth_verifier=ZZZZ
        url.query => oauth_token=XXXX&oauth_verifier=ZZZZ
        url.query?.urlQueryStringParameters => ["oauth_token": "XXXX", "oauth_verifier": "YYYY"]
        */
        guard let verifier = parameters["oauth_verifier"] else { return }
        // Start Step 3: Request Access Token
        let accessTokenInput = RequestAccessTokenInput(consumerKey: TWITTER_CONSUMER_KEY,
                                                       consumerSecret: TWITTER_CONSUMER_SECRET,
                                                       requestToken: oAuthTokenResponse.oauthToken,
                                                       requestTokenSecret: oAuthTokenResponse.oauthTokenSecret,
                                                       oauthVerifier: verifier)
        self.requestAccessToken(args: accessTokenInput) { accessTokenResponse in
          // Process Completed Successfully!
          DispatchQueue.main.async {
            self.credential = accessTokenResponse
            self.authUrl = nil
              self.getTweets()
          }
        }
    }

  
}

extension String {
  var urlQueryStringParameters: Dictionary<String, String> {
    // breaks apart query string into a dictionary of values
    var params = [String: String]()
    let items = self.split(separator: "&")
    for item in items {
      let combo = item.split(separator: "=")
      if combo.count == 2 {
        let key = "\(combo[0])"
        let val = "\(combo[1])"
        params[key] = val
      }
    }
    return params
  }
}

extension String {
  var urlEncoded: String {
    var charset: CharacterSet = .urlQueryAllowed
    charset.remove(charactersIn: "\n:#/?@!$&'()*+,;=")
    return self.addingPercentEncoding(withAllowedCharacters: charset)!
  }
}
