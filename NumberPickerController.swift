//
//  NumberPickerController.swift
//  ListAdder
//
//  Translated by OOPer in cooperation with shlab.jp, on 2015/2/8.
//
//
/*
     File: NumberPickerController.h
     File: NumberPickerController.m
 Abstract: Controller that lets the user pick a number.
  Version: 1.1

 Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple
 Inc. ("Apple") in consideration of your agreement to the following
 terms, and your use, installation, modification or redistribution of
 this Apple software constitutes acceptance of these terms.  If you do
 not agree with these terms, please do not use, install, modify or
 redistribute this Apple software.

 In consideration of your agreement to abide by the following terms, and
 subject to these terms, Apple grants you a personal, non-exclusive
 license, under Apple's copyrights in this original Apple software (the
 "Apple Software"), to use, reproduce, modify and redistribute the Apple
 Software, with or without modifications, in source and/or binary forms;
 provided that if you redistribute the Apple Software in its entirety and
 without modifications, you must retain this notice and the following
 text and disclaimers in all such redistributions of the Apple Software.
 Neither the name, trademarks, service marks or logos of Apple Inc. may
 be used to endorse or promote products derived from the Apple Software
 without specific prior written permission from Apple.  Except as
 expressly stated in this notice, no other rights or licenses, express or
 implied, are granted by Apple herein, including but not limited to any
 patent rights that may be infringed by your derivative works or by other
 works in which the Apple Software may be incorporated.

 The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
 MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
 THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
 FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
 OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.

 IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
 OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
 MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
 AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
 STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
 POSSIBILITY OF SUCH DAMAGE.

 Copyright (C) 2014 Apple Inc. All Rights Reserved.

 */

import UIKit

@objc(NumberPickerControllerDelegate)
protocol NumberPickerControllerDelegate: NSObjectProtocol {
    
    // number is nil on cancel
    func numberPicker(_ controller: NumberPickerController, didChooseNumber number: NSNumber?)
    
}

// NumberCell is a trivial subclass of UITableViewCell that allows us
// to set the number in IB via the "user defined runtime attributes"
// inspector.

@objc(NumberCell)
class NumberCell: UITableViewCell {
    
    @NSCopying var number: NSNumber!
    
}

@objc(NumberPickerController)
class NumberPickerController: UITableViewController {
    weak var delegate: NumberPickerControllerDelegate?
    
    private func didChooseNumber(_ number: NSNumber?) {
        
        // number may be nil
        
        let strongDelegate = self.delegate
        strongDelegate?.numberPicker(self, didChooseNumber: number)
    }
    
    override func tableView(_ tv: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        assert(tv === self.tableView)
        
        let cell = self.tableView.cellForRow(at: indexPath) as! NumberCell
        
        self.tableView.deselectRow(at: indexPath, animated: true)
        
        self.didChooseNumber(cell.number)
    }
    
    @IBAction func cancelAction(_: AnyObject) {
        self.didChooseNumber(nil)
    }
    
}
