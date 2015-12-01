//
//  PendingMessage.swift
//  ConversationKit
//
//  Created by Ben Gottlieb on 11/30/15.
//  Copyright © 2015 Stand Alone, Inc. All rights reserved.
//

import Foundation
import CloudKit

extension Cloud {
	
}


class PendingMessage {
	static var recordName = "ConversationKitPending"
	
	let speaker: Speaker!
	let pendingAt: NSDate!
	
	init?(speaker who: Speaker, cachedPendingAt: NSDate?) {
		speaker = who
		pendingAt = cachedPendingAt
		if speaker == nil || pendingAt == nil { return nil }
	}
	
	init(speaker who: Speaker) {
		speaker = who
		pendingAt = NSDate()
		
		self.saveToCloud()
	}
	
	var recordIDName: String? {
		guard let local = Speaker.localSpeaker else { return nil }
		return "\(local.identifier) -> \(self.speaker.identifier)"
	}
	
	var recordID: CKRecordID? { if let name = self.recordIDName { return CKRecordID(recordName: name) }; return nil }
	
	func delete() {
		guard let recordID = self.recordID else { return }
		
		Cloud.instance.database.deleteRecordWithID(recordID) { recordID, error in
			if error != nil { ConversationKit.log("Failed to delete pending message", error: error) }
		}
	}
	
	func saveToCloud() {
		guard let recordID = self.recordID, local = Speaker.localSpeaker else { return }
		
		Cloud.instance.database.fetchRecordWithID(recordID) { existing, error in
			if existing == nil {		//create it
				let record = CKRecord(recordType: PendingMessage.recordName, recordID: recordID)
				record["recipient"] = self.speaker.identifier
				record["speaker"] = local.identifier
				record["lastPendingAt"] = NSDate()
				Cloud.instance.database.saveRecord(record, completionHandler: { record, error in
					if error != nil { ConversationKit.log("Failed to save pending message", error: error) }
				})
			}
		}
	}
}

extension Conversation {
	public var hasPendingMessage: Bool {
			set {
				if newValue {
					if self.nonLocalSpeaker.pending == nil {
						self.nonLocalSpeaker.pending = PendingMessage(speaker: self.nonLocalSpeaker)
					}
				} else {
					self.nonLocalSpeaker.pending?.delete()
					self.nonLocalSpeaker.pending = nil
				}
			}

			get {
				return self.nonLocalSpeaker.pending != nil
			}
		}
	
}