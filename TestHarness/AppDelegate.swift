//
//  AppDelegate.swift
//  TestHarness
//
//  Created by Ben Gottlieb on 11/15/15.
//  Copyright © 2015 Stand Alone, Inc. All rights reserved.
//

import UIKit
import ConversationKit
import CloudKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

	var window: UIWindow?


	func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
		ConversationKit.configureNotifications(application)

		ConversationKit.fetchAccountIdentifier { identifier in
			guard let ident = identifier else { return }
			ConversationKit.setup() { setup in
				ConversationKit.setupLocalSpeaker(ident) { success in
					Speaker.localSpeaker.tags = ["tester"]
					Speaker.localSpeaker.save { success in
						print("saved local speaker \(success)")
					}
				}
			}
		}
		
		
		self.window = UIWindow(frame: UIScreen.mainScreen().bounds)
		self.window?.rootViewController = UINavigationController(rootViewController: TestViewController(conversation: nil))
		
		self.window?.makeKeyAndVisible()
		
		
		// Override point for customization after application launch.
		return true
	}

	func application(application: UIApplication, didReceiveRemoteNotification userInfo: [NSObject : AnyObject], fetchCompletionHandler completionHandler: (UIBackgroundFetchResult) -> Void) {
		ConversationKit.application(application, didReceiveRemoteNotification: userInfo, fetchCompletionHandler: completionHandler)
	}

}

