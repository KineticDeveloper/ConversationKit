//
//  Speaker.swift
//  ConversationKit
//
//  Created by Ben Gottlieb on 11/15/15.
//  Copyright © 2015 Stand Alone, inc. All rights reserved.
//

import Foundation
import CoreData
import CloudKit

public class Speaker: CloudObject {
	public var identifier: String? { didSet {
		if self.identifier != oldValue {
			self.needsCloudSave = true
			self.cloudKitRecordID = Speaker.cloudKitRecordIDFromIdentifier(self.identifier)
		}
	}}
	public var name: String? { didSet { if self.name != oldValue { self.needsCloudSave = true }}}
	public var isLocalSpeaker = false
	
	public static var localSpeaker: Speaker = {
		let speaker = Speaker()
		speaker.isLocalSpeaker = true
		let moc = DataStore.instance.privateContext
		moc.performBlockAndWait {
			if let spkr: SpeakerRecord = moc.anyObject(NSPredicate(format: "isLocalSpeaker = true")) {
				speaker.loadWithManagedObject(spkr)
			}
		}
		Speaker.addKnownSpeaker(speaker)
		return speaker
	}()
	
	
	var cloudKitReference: CKReference? { if let recordID = self.cloudKitRecordID { return CKReference(recordID: recordID, action: .None) } else { return nil } }
	
	static var knownSpeakers = Set<Speaker>()
	class func addKnownSpeaker(spkr: Speaker) { dispatch_sync(ConversationKit.instance.queue) { self.knownSpeakers.insert(spkr) } }
	class func cloudKitRecordIDFromIdentifier(identifier: String?) -> CKRecordID? {
		if let ident = identifier {
			return CKRecordID(recordName: "Speaker: " + ident)
		}
		return nil
	}
	
	internal class func speakerFromRecordID(recordID: CKRecordID) -> Speaker? {
		for speaker in self.knownSpeakers {
			if speaker.cloudKitRecordID == recordID { return speaker }
		}
		return nil
	}

	internal class func loadSpeakerFromRecordID(recordID: CKRecordID, completion: ((Speaker?) -> Void)?) -> Speaker? {
		Cloud.instance.database.fetchRecordWithID(recordID) { record, error in
			if let record = record {
				let speaker = Speaker()
				speaker.loadWithCloudKitRecord(record)
				Speaker.addKnownSpeaker(speaker)
				
				completion?(speaker)
			} else {
				Cloud.instance.reportError(error, note: "Problem loading speaker with ID \(recordID)")
				completion?(nil)
			}
		}
		
		return nil
	}
	
	override func readFromCloudKitRecord(record: CKRecord) {
		identifier = record["identifier"] as? String
		name = record["name"] as? String
	}
	
	override func didCreateFromServerRecord() {
		Cloud.instance.pullDownMessages()
	}
	
	override func writeToCloudKitRecord(record: CKRecord) -> Bool {
		if (record["identifier"] as? String) == self.identifier && (record["name"] as? String) == self.name { return false }
		
		record["identifier"] = self.identifier
		record["name"] = self.name
		return true
	}
	
	override func readFromManagedObject(object: ManagedCloudObject) {
		guard let spkr = object as? SpeakerRecord else { return }
		
		self.identifier = spkr.identifier
		self.name = spkr.name
	}
	
	override func writeToManagedObject(object: ManagedCloudObject) {
		guard let speakerObject = object as? SpeakerRecord else { return }
		speakerObject.name = self.name
		speakerObject.identifier = self.identifier
		speakerObject.isLocalSpeaker = self.isLocalSpeaker
	}

	internal override class var recordName: String { return "Speaker" }
	internal override class var entityName: String { return "SpeakerRecord" }

	internal override var canSaveToCloud: Bool { return self.identifier != nil }
}

public func ==(lhs: Speaker, rhs: Speaker) -> Bool {
	return lhs.identifier == rhs.identifier
}

internal class SpeakerRecord: ManagedCloudObject {
	@NSManaged var identifier: String?
	@NSManaged var name: String?
	@NSManaged var isLocalSpeaker: Bool
}