//
//  MessageTableViewCell.swift
//  ConversationKit
//
//  Created by Ben Gottlieb on 11/22/15.
//  Copyright © 2015 Stand Alone, Inc. All rights reserved.
//

import UIKit
import ConversationKit

class MessageTableViewCell: UITableViewCell {
	static let identifier = "MessageTableViewCell"
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
	
	var message: Message? { didSet {
		self.textLabel?.text = self.message?.content
	}}
    
}
