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
			self.cloudKitRecordID = self.identifier == nil ? nil : CKRecordID(recordName: "Speaker: " + self.identifier!)
		}
	}}
	public var name: String? { didSet { if self.name != oldValue { self.needsCloudSave = true }}}
	public var isLocalSpeaker = false
	
	static var knownSpeakers = Set<Speaker>()
	class func addKnownSpeaker(spkr: Speaker) { dispatch_sync(ConversationKit.instance.queue) { self.knownSpeakers.insert(spkr) } }
	
	public static var localSpeaker: Speaker = {
		let speaker = Speaker()
		speaker.isLocalSpeaker = true
		let moc = DataStore.instance.privateContext
		moc.performBlockAndWait {
			if let spkr: SpeakerRecord = moc.anyObject(NSPredicate(format: "isLocalSpeaker = true")) {
				speaker.identifier = spkr.identifier
				speaker.name = spkr.name
				speaker.recordID = spkr.objectID
				speaker.needsCloudSave = spkr.needsCloudSave
			}
		}
		Speaker.addKnownSpeaker(speaker)
		return speaker
	}()
	
	override func loadFromCloudKitRecord(record: CKRecord) {
		identifier = record["identifier"] as? String
		name = record["name"] as? String
	}
	
	override func writeToCloudKitRecord(record: CKRecord) -> Bool {
		if (record["identifier"] as? String) == self.identifier && (record["name"] as? String) == self.name { return false }
		
		record["identifier"] = self.identifier
		record["name"] = self.name
		return true
	}
	
	override func writeToManagedObject(object: ManagedCloudObject) {
		guard let speakerObject = object as? SpeakerRecord else { return }
		speakerObject.name = self.name
		speakerObject.identifier = self.identifier
		speakerObject.isLocalSpeaker = self.isLocalSpeaker
	}

	internal override class var recordName: String { return "Speaker" }
	internal override class var entityName: String { return "SpeakerRecord" }

}

public func ==(lhs: Speaker, rhs: Speaker) -> Bool {
	return lhs.identifier == rhs.identifier
}

internal class SpeakerRecord: ManagedCloudObject {
	@NSManaged var identifier: String?
	@NSManaged var name: String?
	@NSManaged var isLocalSpeaker: Bool
}