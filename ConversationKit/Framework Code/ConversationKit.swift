//
//  ConversationKit.swift
//  ConversationKit
//
//  Created by Ben Gottlieb on 11/14/15.
//  Copyright (c) 2015 Stand Alone, inc. All rights reserved.
//

import Foundation

public class ConversationKit: NSObject {
	public static let instance = ConversationKit()
	
	public struct notifications {
		public static let setupComplete = "ConversationKit.setupComplete"
		public static let updateComplete = "ConversationKit.updateComplete"
	}
	
	override init() {
		super.init()
	}
	
	public func setup(containerName: String? = nil, localSpeakerName: String, localSpeakerIdentifier: String, completion: (Bool) -> Void) {
		
		Cloud.instance.setup(containerName) {
			Speaker.localSpeaker.name = localSpeakerName
			Speaker.localSpeaker.identifier = localSpeakerIdentifier
			Speaker.localSpeaker.saveToCloudKit { success in
				Utilities.postNotification(ConversationKit.notifications.setupComplete)
				
				completion(success)
			}
		}
	}
	internal let queue = dispatch_queue_create("ConversationKitQueue", DISPATCH_QUEUE_SERIAL)
}