//
//  Cloud.swift
//  ConversationKit
//
//  Created by Ben Gottlieb on 11/15/15.
//  Copyright © 2015 Stand Alone, inc. All rights reserved.
//

import Foundation
import CloudKit
import CoreData

public class Cloud: NSObject {
	let lastPendingFetchedAtKey = "lastFetchedAt"

	static let instance = Cloud()
	
	public var configured = false
	public var iCloudAccountIDAvailable = false
	public var setupComplete = false
	public var container: CKContainer!
	public var database: CKDatabase!
	
	public func setup(containerID: String? = nil, completion: (Bool) -> Void) {
		dispatch_async(self.queue) {
			if self.setupComplete {
				completion(self.configured)
				return
			}
			self.container = (containerID == nil) ? CKContainer.defaultContainer() : CKContainer(identifier: containerID!)
			self.database = self.container.publicCloudDatabase
			
			self.container.accountStatusWithCompletionHandler { status, error in
				if let err = error {
					ConversationKit.log("Error while configuring CloudKit: \(err)")
				} else {
					switch status {
					case .Available:
						self.configured = true
						self.iCloudAccountIDAvailable = true

					case .CouldNotDetermine:
						ConversationKit.log("Unknown CloudKit status")
					case .NoAccount:
						ConversationKit.log("No account set up")
						self.configured = true
						self.iCloudAccountIDAvailable = false

					case .Restricted:
						ConversationKit.log("Restricted: no access to CloudKit account")
						
					}
				}
				
				self.setupComplete = true
				completion(self.configured)
			}
		}
	}
	
	var queryOperation: CKQueryOperation?
	
	var parsingContext: NSManagedObjectContext!
	
	func pullDownMessages(all: Bool = false) {
		guard self.configured, let localUserID = Speaker.localSpeaker.identifier else { return }
		
		if self.queryOperation == nil {
			ConversationKit.instance.networkActivityUsageCount++
			var pred = NSPredicate(format: "speakers contains %@", localUserID)
			
			if !all, let date = DataStore.instance[self.lastPendingFetchedAtKey] as? NSDate {
				pred = NSCompoundPredicate(andPredicateWithSubpredicates: [pred, NSPredicate(format: "spokenAt > %@", date)])
				ConversationKit.log("pulling down messages for \(localUserID) starting at \(date)")
			} else {
				ConversationKit.log("pulling all messages down for \(localUserID)")
			}
			
			DataStore.instance[self.lastPendingFetchedAtKey] = NSDate()
			let query = CKQuery(recordType: Message.recordName, predicate: pred)
			self.queryOperation = CKQueryOperation(query: query)
			self.parsingContext = DataStore.instance.createWorkerContext()
			
			self.queryOperation!.recordFetchedBlock = { record in
				let moc = self.parsingContext
				moc.performBlock {
					if !Message.recordExists(record, inContext: moc), let message = Message(record: record) {
						message.saveManagedObject(inContext: moc)
						ConversationKit.log("\(message.content)")
						Conversation.conversationWithSpeaker(message.speaker, listener: message.listener).addMessage(message, from: .iCloudCache)
					}
				}
			}
			
			self.queryOperation!.queryCompletionBlock = { cursor, error in
				let moc = self.parsingContext
				moc.performBlock {
					ConversationKit.log("message loading complete")
					moc.safeSave()
					self.queryOperation = nil
					self.parsingContext = nil
					Utilities.postNotification(ConversationKit.notifications.finishedLoadingMessagesOldMessages)
					Utilities.postNotification(ConversationKit.notifications.setupComplete)
					ConversationKit.instance.networkActivityUsageCount--
				}
			}
			
			self.database.addOperation(self.queryOperation!)
		}
	}
	
	let messageSubscriptionID = "messageSubscriptionID"
	var subscription: CKSubscription?

	public func setupSubscription() {
		guard self.configured, let localUserID = Speaker.localSpeaker.identifier else { return }
		
		if self.subscription == nil {
			let pred = NSPredicate(format: "speakers contains %@", localUserID)
			self.subscription = CKSubscription(recordType: Message.recordName, predicate: pred, subscriptionID: self.messageSubscriptionID, options: .FiresOnRecordCreation)
			let info = CKNotificationInfo()
			info.alertBody = "Test Alert"
			info.alertLocalizationKey = "%1$@ : %2$@"
			info.shouldSendContentAvailable = true
			info.alertLocalizationArgs = ["speakerName", "content"]
			
			self.subscription?.notificationInfo = info
			self.database.saveSubscription(self.subscription!, completionHandler: { sub, error in
				ConversationKit.log("Finished Creating Subscription: \(sub): \(error)")
			})
		}
	}
	
	internal func handleNotificationCloudRecordID(recordID: CKRecordID) {
		self.database.fetchRecordWithID(recordID) { incoming, error in
			if let record = incoming {
				if record.recordType == Message.recordName {
					
					DataStore.instance.importBlock { moc in
						if !Message.recordExists(record, inContext: moc), let message = Message(record: record) {
							message.saveManagedObject(inContext: moc)
							ConversationKit.log("\(message.content)")
							Conversation.conversationWithSpeaker(message.speaker, listener: message.listener).addMessage(message, from: .iCloudCache)
						}
					}
				}
			}
		}
	}
	
	internal func reportError(error: NSError?, note: String) {
		guard let error = error else { return }
		
		ConversationKit.log("\(note): \(error)")
	}
	
	internal let queue = dispatch_queue_create("ConversationKitCloudQueue", DISPATCH_QUEUE_SERIAL)
}
