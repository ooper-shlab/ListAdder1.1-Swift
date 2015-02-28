//
//  ListAdderViewController.swift
//  ListAdder
//
//  Translated by OOPer in cooperation with shlab.jp, on 2015/2/8.
//
//
/*
     File: ListAdderViewController.h
     File: ListAdderViewController.m
 Abstract: Main view controller.
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

@objc(ListAdderViewController)
class ListAdderViewController: UITableViewController,
NumberPickerControllerDelegate, OptionsControllerDelegate {
    
    // private properties
    
    private var numbers: NSMutableArray!
    private var queue: NSOperationQueue!
    private lazy var queueContext: UnsafeMutablePointer<Void> = withUnsafeMutablePointer(&self.queue) {UnsafeMutablePointer($0)}
    dynamic private var recalculating: Bool = false
    private lazy var recalculatingContext: UnsafeMutablePointer<Void> = withUnsafeMutablePointer(&self.recalculating) {UnsafeMutablePointer($0)}
    private var inProgressAdder: AdderOperation?
    private var formattedTotal: String?
    private lazy var totalContext: UnsafeMutablePointer<Void> = withUnsafeMutablePointer(&self.formattedTotal) {UnsafeMutablePointer($0)}
    
    // Returns 'M' if we're running on the main thread, or 'S' otherwies.
    private final func CharForCurrentThread()->UInt32 {
        return NSThread.isMainThread() ? UInt32("M") : UInt32("S")
    }
    
    // Returns the default numbers that we initialise the view with.
    private class func defaultNumbers() -> NSArray {
        return [7, 5, 8, 9, 7, 6]
    }
    
    // Set up some private properties.
    override func awakeFromNib() {
        
        self.numbers = self.dynamicType.defaultNumbers().mutableCopy() as! NSMutableArray
        assert(self.numbers != nil)
        
        self.queue = NSOperationQueue()
        assert(self.queue != nil)
        
        // Observe .recalculating to trigger reloads of the cell in the first
        // section (kListAdderSectionIndexTotal).
        
        self.addObserver(self, forKeyPath: "recalculating", options: nil, context: recalculatingContext)
    }
    
    // This is the root view controller of our application, so it can never be
    // deallocated.  Supporting -dealloc in a view controller in the presence of
    // threading, even highly constrained threading as used by this example, is
    // tricky.  I generally recommend that you avoid this, and confine your threads
    // to your model layer code.  If that's not possible, you can use a technique
    // like that shown in the QWatchedOperationQueue class in the LinkedImageFetcher
    // sample code.
    //
    // <http://developer.apple.com/mac/library/samplecode/LinkedImageFetcher/>
    //
    // However, I didn't want to drag parts of that sample into this sample (especially
    // given that -dealloc can never be called in this sample and thus I can't test it),
    // nor did I want to demonstrate an ad hoc, and potentially buggy, version of
    // -dealloc.  So, for the moment, we just don't support -dealloc.
    deinit {
        
        assert(false)
        
        // Despite the above, I've left in the following just as an example of how you
        // manage self observation in a view controller.
        
        self.removeObserver(self, forKeyPath: "recalculating", context: recalculatingContext)
    }
    
    private func syncLeftBarButtonTitle() {
        if self.numbers.count <= 1 {
            self.navigationItem.leftBarButtonItem?.title = "Defaults"
        } else {
            self.navigationItem.leftBarButtonItem?.title = "Minimum"
        }
    }
    
    //MARK: * View controller stuff
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Configure our table view.
        
        self.tableView.editing = true
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        // When we come on screen, if we don't have a current value and we're not
        // already calculating a value, kick off an operation to calculate the initial
        // value of the total.
        
        if self.formattedTotal == nil && !self.recalculating {
            self.recalculateTotal()
        }
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender _: AnyObject?) {
        
        // Dispatch to our various segue-specific methods.
        
        if segue.identifier == "numberPicker" {
            self.prepareForNumberPickerSegue(segue)
        } else if segue.identifier == "options" {
            self.prepareForOptionsSegue(segue)
        } else {
            assert(false)     // What segue?
        }
    }
    
    //MARK: * Table view callbacks
    
    private final let kListAdderSectionIndexTotal = 0
    private final let kListAdderSectionIndexAddNumber = 1
    private final let kListAdderSectionIndexNumbers = 2
    private final let kListAdderSectionIndexCount = 3
    
    override func numberOfSectionsInTableView(tv: UITableView) -> Int {
        assert(tv === self.tableView)
        return kListAdderSectionIndexCount
    }
    
    override func tableView(tv: UITableView, numberOfRowsInSection section: Int) -> Int {
        assert(tv === self.tableView)
        assert(section < kListAdderSectionIndexCount)
        
        return (section == kListAdderSectionIndexNumbers) ? self.numbers.count : 1
    }
    
    private func isValidIndexPath(indexPath: NSIndexPath?) -> Bool {
        return (indexPath != nil) &&
            ((indexPath!.section >= 0) && (indexPath!.section < kListAdderSectionIndexCount)) &&
            (indexPath!.row >= 0) &&
            (indexPath!.row < ((indexPath!.section == kListAdderSectionIndexNumbers) ? self.numbers.count : 1))
    }
    
    override func tableView(tv: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        var cell: UITableViewCell!
        
        assert(tv === self.tableView)
        assert(self.isValidIndexPath(indexPath))
        
        // Previously this code used a single prototype cell and configured it as needed.
        // This breaks on iOS 8.0, where the detailed text doesn't show up in some
        // circumstances <rdar://problem/17682058>.  To work around this I now use
        // multiple cell prototypes, one for each class of cell.  This had the added
        // advantage of making the code smaller, putting all the UI strings in the
        // storyboard, and so on.
        
        // Set it up based on the section and row.
        
        switch indexPath.section {
        case kListAdderSectionIndexTotal:
            if self.recalculating {
                
                cell = self.tableView.dequeueReusableCellWithIdentifier("totalBusy") as! UITableViewCell!
                assert(cell != nil)
                
                let activityView = cell.editingAccessoryView as! UIActivityIndicatorView
                activityView.startAnimating()
            } else {
                cell = self.tableView.dequeueReusableCellWithIdentifier("total") as! UITableViewCell!
                assert(cell != nil)
                cell.detailTextLabel?.text = self.formattedTotal
            }
        case kListAdderSectionIndexAddNumber:
            cell = self.tableView.dequeueReusableCellWithIdentifier("add") as! UITableViewCell!
            assert(cell != nil)
        case kListAdderSectionIndexNumbers:
            cell = self.tableView.dequeueReusableCellWithIdentifier("number") as! UITableViewCell!
            assert(cell != nil)
            cell.textLabel?.text = NSNumberFormatter.localizedStringFromNumber(self.numbers[indexPath.row] as! NSNumber, numberStyle: .DecimalStyle)
        default:
            assertionFailure(__FUNCTION__)
        }
        
        return cell
    }
    
    override func tableView(tv: UITableView, editingStyleForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCellEditingStyle {
        var result: UITableViewCellEditingStyle
        
        assert(tv === self.tableView)
        assert(self.isValidIndexPath(indexPath))
        
        switch indexPath.section {
        case kListAdderSectionIndexTotal:
            result = .None
        case kListAdderSectionIndexAddNumber:
            result = .Insert
        case kListAdderSectionIndexNumbers:
            // We don't allow the user to delete the last cell.
            if self.numbers.count == 1 {
                result = .None
            } else {
                result = .Delete
            }
        default:
            assertionFailure(__FUNCTION__)
        }
        return result
    }
    
    // I would like to suppress the delete confirmation button but I don't think there's a
    // supported way to do this.
    
    override func tableView(tv: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        assert(tv === self.tableView)
        assert(self.isValidIndexPath(indexPath))
        
        switch indexPath.section {
        case kListAdderSectionIndexTotal:
            assertionFailure(__FUNCTION__)
        case kListAdderSectionIndexAddNumber:
            assert(editingStyle == .Insert)
            
            // The user has tapped on the plus button itself (as opposed to the body
            // of that cell).  Bring up the number picker.
            
            self.presentNumberPickerModally()
        case kListAdderSectionIndexNumbers:
            assert(editingStyle == .Delete)
            assert(self.numbers.count != 0)      // because otherwise we'd have no delete button
            
            // Remove the row from our model and the table view.
            
            self.numbers.removeObjectAtIndex(indexPath.row)
            self.tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .None)
            
            // If we've transitioned from 2 rows to 1 row, remove the delete button for the
            // remaining row; we don't want folks deleting that now, do we?  Also, set the
            // title of the left bar button to "Defaults" to reflect its updated function.
            
            if self.numbers.count == 1 {
                self.tableView.reloadRowsAtIndexPaths([NSIndexPath(forRow: 0, inSection:kListAdderSectionIndexNumbers)], withRowAnimation: .None)
                
                self.syncLeftBarButtonTitle()
            }
            
            // We've modified numbers, so kick off a recalculation.
            
            self.recalculateTotal()
        default:
            assertionFailure(__FUNCTION__)
        }
    }
    
    override func tableView(tv: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        
        assert(tv === self.tableView)
        assert(self.isValidIndexPath(indexPath))
        
        self.tableView.deselectRowAtIndexPath(indexPath, animated: true)
        
        switch indexPath.section {
        case kListAdderSectionIndexTotal:
            // do nothing
            break
        case kListAdderSectionIndexAddNumber:
            
            // The user has tapped on the body of the cell associated with plus button.
            // Bring up the number picker.
            
            self.presentNumberPickerModally()
        case kListAdderSectionIndexNumbers:
            // do nothing
            break
        default:
            assertionFailure(__FUNCTION__)
        }
    }
    
    //MARK: * Number picker management
    
    private func presentNumberPickerModally() {
        self.performSegueWithIdentifier("numberPicker", sender: self)
    }
    
    private func prepareForNumberPickerSegue(segue: UIStoryboardSegue) {
        
        let nav = segue.destinationViewController as! UINavigationController
        
        let numberPicker = nav.viewControllers[0] as! NumberPickerController
        
        numberPicker.delegate = self
    }
    
    // Called by the number picker when the user chooses a number or taps cancel.
    func numberPicker(controller: NumberPickerController, didChooseNumber number: NSNumber?) {
        
        // If it wasn't cancelled...
        
        if number != nil {
            
            // Add the number to our model and the table view.
            
            self.numbers.addObject(number!)
            self.tableView.insertRowsAtIndexPaths([NSIndexPath(forRow: self.numbers.count - 1, inSection: kListAdderSectionIndexNumbers)], withRowAnimation: .None)
            
            // If we've transitioned from 1 row to 2 rows, add the delete button back for
            // the first row.  Also change the left bar button item back to "Minimum".
            
            if self.numbers.count == 2 {
                self.tableView.reloadRowsAtIndexPaths([NSIndexPath(forRow: 0, inSection: kListAdderSectionIndexNumbers)], withRowAnimation: .None)
                
                self.syncLeftBarButtonTitle()
            }
            
            // We've modified numbers, so kick off a recalculation.
            
            self.recalculateTotal()
        }
        self.dismissViewControllerAnimated(true, completion: nil)
    }
    
    //MARK: * Options management
    
    private func prepareForOptionsSegue(segue: UIStoryboardSegue) {
        
        let nav = segue.destinationViewController as! UINavigationController
        
        let options = nav.viewControllers[0] as! OptionsController
        
        options.delegate = self
    }
    
    // Called when the user taps Save in the options view.  The options
    // view has already saved the options, so we have nothing to do other
    // than to tear down the view.
    func didSaveOptions(OptionsController) {
        self.dismissViewControllerAnimated(true, completion: nil)
    }
    
    // Called when the user taps Cancel in the options view.
    func didCancelOptions(OptionsController) {
        self.dismissViewControllerAnimated(true, completion: nil)
    }
    
    //MARK: * Async recalculation
    
    // Starts a recalculation using either the thread- or NSOperation-based code.
    private func recalculateTotal() {
        if NSUserDefaults.standardUserDefaults().boolForKey("useThreadsDirectly") {
            self.recalculateTotalUsingThread()
        } else {
            self.recalculateTotalUsingOperation()
        }
    }
    
    //MARK: - NSThread
    
    // Starts a recalculation using a thread.
    private func recalculateTotalUsingThread() {
        if NSUserDefaults.standardUserDefaults().boolForKey("retainNotCopy") {
            self.recalculating = true
            
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
                self.threadRecalculateNumbers(self.numbers)
            }
        } else {
            
            self.recalculating = true
            
            let immutableNumbers = self.numbers.copy() as! NSArray
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
                self.threadRecalculateNumbers(immutableNumbers)
            }
        }
    }
    
    // Does the actual recalculation when we're in threaded mode.  Always
    // called on a secondary thread.
    private func threadRecalculateNumbers(immutableNumbers: NSArray) {
        autoreleasepool  {
            
            assert(!NSThread.isMainThread())
            
            var total = 0
            let numberCount = immutableNumbers.count
            for numberObj in immutableNumbers as! [NSNumber] {
                
                // Sleep for a while.  This makes it easiest to test various problematic cases.
                
                NSThread.sleepForTimeInterval(1.0)
                
                // Do the maths.
                
                total += numberObj.integerValue
            }
            
            let totalStr = String(format: "%ld", total)
            if NSUserDefaults.standardUserDefaults().boolForKey("applyResultsFromThread") {
                self.formattedTotal = totalStr
                self.recalculating = false
            } else {
                dispatch_async(dispatch_get_main_queue()) {
                    self.threadRecalculateDone(totalStr)
                }
            }
        }
    }
    
    // In threaded mode, called on the main thread to apply the results to the UI.
    private func threadRecalculateDone(result: String) {
        assert(NSThread.isMainThread())
        
        // The user interface is adjusted by a KVO observer on recalculating.
        
        self.formattedTotal = result
        self.recalculating = false
    }
    
    private func threadRecalculateNumbers() {
        autoreleasepool {
            
            // IMPORTANT: This method is not actually used.  It is here because it's a code
            // snippet in the technote, and i wanted to make sure it compiles.
            
            assertionFailure(__FUNCTION__)
            
            var total = 0
            for numberObj in self.numbers as NSArray as! [NSNumber] {
                
                // Sleep for a while.  This makes it easiest to test various problematic cases.
                
                NSThread.sleepForTimeInterval(1.0)
                
                // Do the maths.
                
                total += numberObj.integerValue
            }
            
            // The user interface is adjusted by a KVO observer on recalculating.
            
            let totalStr = String(format: "%ld", total)
            self.formattedTotal = totalStr
            self.recalculating = false
        }
    }
    
    private func threadRecalculateNumbers2() {
        autoreleasepool {
            
            // IMPORTANT: This method is not actually used.  It is here because it's a code
            // snippet in the technote, and i wanted to make sure it compiles.
            
            assertionFailure(__FUNCTION__)
            
            var total = 0
            for numberObj in self.numbers as NSArray as! [NSNumber] {
                
                // Sleep for a while.  This makes it easiest to test various problematic cases.
                
                NSThread.sleepForTimeInterval(1.0)
                
                // Do the maths.
                
                total += numberObj.integerValue
            }
            
            // Update the user interface on the main thread.
            
            let totalStr = String(format: "%ld", total)
            dispatch_async(dispatch_get_main_queue()) {
                self.threadRecalculateDone(totalStr)
            }
        }
    }
    
    //MARK: - NSOperation
    
    // Starts a recalculation using an NSOperation.
    private func recalculateTotalUsingOperation() {
        // If we're already calculating, cancel that operation.  It's going to
        // yield stale results.  We don't remove the observer here, but rather
        // remove the observer when it completes.  Also, we don't nil out
        // inProgressAdder because it'll just get replaced in the next line
        // and changing the value triggers an unnecessary KVO notification of
        // recalculating.
        
        if self.inProgressAdder != nil {
            fputs(String(format: "%c %3ld cancelled\n", CharForCurrentThread(), self.inProgressAdder!.sequenceNumber), stderr)
            self.inProgressAdder!.cancel()
        }
        
        // Start up a replacement operation.
        
        self.inProgressAdder = AdderOperation(numbers: self.numbers)
        assert(self.inProgressAdder != nil)
        if NSUserDefaults.standardUserDefaults().boolForKey("addFaster") {
            self.inProgressAdder!.interNumberDelay = 0.2
        }
        
        self.inProgressAdder!.addObserver(self, forKeyPath: "isFinished", options: nil, context: totalContext)
        self.inProgressAdder!.addObserver(self, forKeyPath: "isExecuting", options: nil, context: queueContext)
        
        fputs(String(format: "%c %3ld queuing\n", CharForCurrentThread(), self.inProgressAdder!.sequenceNumber), stderr)
        self.queue.addOperation(self.inProgressAdder!)
        
        // The user interface is adjusted by a KVO observer on recalculating.
        
        self.recalculating = true
    }
    
    override func observeValueForKeyPath(keyPath: String, ofObject object: AnyObject, change: [NSObject : AnyObject], context: UnsafeMutablePointer<Void>) {
        if context == totalContext {
            
            // If the operation has finished, call -adderOperationDone: on the main thread to deal
            // with the results.
            
            // can be running on any thread
            assert(keyPath == "isFinished")
            let op = object as! AdderOperation
            assert(op.finished)
            
            fputs(String(format: "%c %3ld finished\n", CharForCurrentThread(), op.sequenceNumber), stderr)
            if NSUserDefaults.standardUserDefaults().boolForKey("applyResultsFromThread") {
                self.adderOperationDone(op)
            } else {
                if NSUserDefaults.standardUserDefaults().boolForKey("allowStale") {
                    dispatch_async(dispatch_get_main_queue()) {
                        self.adderOperationDoneWrong(op)
                    }
                } else {
                    dispatch_async(dispatch_get_main_queue()) {
                        self.adderOperationDone(op)
                    }
                }
            }
        } else if context == queueContext {
            
            // We observe -isExecuting purely for logging purposes.
            
            // can be running on any thread
            assert(keyPath == "isExecuting")
            let op = object as! AdderOperation
            if op.executing {
                fputs(String(format: "%c %3ld executing\n", CharForCurrentThread(), op.sequenceNumber), stderr)
            } else {
                fputs(String(format: "%c %3ld stopped\n", CharForCurrentThread(), op.sequenceNumber), stderr)
            }
        } else if context == recalculatingContext {
            
            // If recalculating changes, reload the first section (kListAdderSectionIndexTotal)
            // which causes the activity indicator to come or go.
            
            assert(NSThread.isMainThread())
            assert(keyPath == "recalculating")
            assert(object === self)
            if self.isViewLoaded() {
                self.tableView.reloadRowsAtIndexPaths([NSIndexPath(forRow: 0, inSection: kListAdderSectionIndexTotal)], withRowAnimation: .None)
            }
        } else {
            super.observeValueForKeyPath(keyPath, ofObject: object, change: change, context: context)
        }
    }
    
    private func adderOperationDone(op: AdderOperation) {
        assert(NSThread.isMainThread())
        
        assert(self.recalculating)
        
        // Always remove our observer, regardless of whether we care about
        // the results of this operation.
        
        fputs(String(format: "%c %3ld done\n", CharForCurrentThread(), op.sequenceNumber), stderr)
        op.removeObserver(self, forKeyPath: "isFinished", context: totalContext)
        op.removeObserver(self, forKeyPath: "isExecuting", context: queueContext)
        
        // Check to see whether these are the results we're looking for.
        // If not, we just discard the results; later on we'll be notified
        // of the latest add operation completing.
        
        if op == self.inProgressAdder {
            assert(!op.cancelled)
            
            // Commit the value to our model.
            
            fputs(String(format: "%c %3lu commit\n", CharForCurrentThread(), op.sequenceNumber), stderr)
            
            self.formattedTotal = op.formattedTotal
            
            // Clear out our record of the operation.  The user interface is adjusted
            // by a KVO observer on recalculating.
            
            self.inProgressAdder = nil
            self.recalculating = false
        } else {
            fputs(String(format: "%c %3lu discard\n", CharForCurrentThread(), op.sequenceNumber), stderr)
        }
    }
    
    private func adderOperationDoneWrong(op: AdderOperation) {
        assert(NSThread.isMainThread())
        
        // Because we're ignoring stale operations, the following assert will
        // trips.
        //
        // assert(self.recalculating);
        
        // Always remove our observer, regardless of whether we care about
        // the results of this operation.
        
        fputs(String(format: "%c %3lu done\n", CharForCurrentThread(), op.sequenceNumber), stderr)
        op.removeObserver(self, forKeyPath: "isFinished", context: totalContext)
        op.removeObserver(self, forKeyPath: "isExecuting", context: queueContext)
        
        // Check to see whether these are the results we're looking for.
        // If not, we just discard the results; later on we'll be notified
        // of the latest add operation completing.
        
        // Because we're ignoring stale operations, the following assert will
        // trips.
        //
        // assert( ! [op isCancelled] );
        
        // Commit the value to our model.
        
        fputs(String(format: "%c %3lu commit\n", CharForCurrentThread(), op.sequenceNumber), stderr)
        
        self.formattedTotal = op.formattedTotal
        
        // Clear out our record of the operation.  The user interface is adjusted
        // by a KVO observer on recalculating.
        
        self.inProgressAdder = nil
        self.recalculating = false
    }
    
    //MARK: * UI actions
    
    // Called when the user taps the left bar button ("Defaults" or "Minimum").
    // If we have lots of numbers, set the list to contain a sigle entry.  If we have
    // just one number, reset the list back to the defaults.  This allows us to easily
    // test cancellation and the discard of stale results.
    @IBAction private func defaultsOrMinimumAction(AnyObject) {
        if self.numbers.count > 1 {
            self.numbers.removeAllObjects()
            self.numbers.addObject(41)
        } else {
            self.numbers.replaceObjectsInRange(NSMakeRange(0, self.numbers.count), withObjectsFromArray: self.dynamicType.defaultNumbers() as [AnyObject])
        }
        self.syncLeftBarButtonTitle()
        if self.isViewLoaded() {
            self.tableView.reloadData()
        }
        self.recalculateTotal()
    }
    
}