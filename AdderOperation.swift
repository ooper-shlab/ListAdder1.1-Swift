//
//  AdderOperation.swift
//  ListAdder
//
//  Translated by OOPer in cooperation with shlab.jp, on 2015/2/7.
//
//
/*
     File: AdderOperation.h
     File: AdderOperation.m
 Abstract: Adds an array of numbers (very slowly) and returns the result.
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

import Foundation

/*
    AdderOperation is an example of using NSOperation to do asynchronous processing
    in a sane fashion.  It follows the thread confinement model.  That is, you
    initialise the operation with an array of numbers to operate on, and it adds up
    those numbers and vends the result through read-only properties.

    The data used by the operation are made thread safe in a number of different ways:

      o Some properties (for example, numbers) are set up at initialisation time and
        can't be changed.  These are immutable, thus can be safely shared between threads.

      o Some properties must be set before the operation is queued and should be immutable
        after that.  Again, these are thread safe because there's no possibility of two
        threads trying to mutate the same value at the same time.  interNumberDelay
        is an example of this.

      o Some properties are set by the operation but shouldn't be read by the client
        until the operation is finished.  total and formattedTotal are examples of this.

      o Some properties, like formatter, are private to the operation and are only ever
        accessed by the thread running the operation.

      o Global data, like sSequenceNumber, is protected by a lock.

    It's obvious that adding a few numbers is going to happen very quickly, so we
    artifically slow things down by sleeping for an extended period of time between
    additions.  This delay is controlled by the interNumberDelay, which defaults to
    one second.
*/

@objc(AdderOperation)
class AdderOperation: NSOperation {
    
    // set up by the init method that can't be changed
    
    let numbers: NSArray                // of NSNumber
    private(set) var sequenceNumber: Int = 0
    
    // must be configured before the operation is started
    
    var interNumberDelay: NSTimeInterval = 1.0
    
    // only meaningful after the operation is finished
    
    private(set) var total: Int = 0
    private(set) var formattedTotal: String = ""
    
    // only accessed by the operation thread
    
    private var formatter: NSNumberFormatter!
    
    init(numbers: NSArray) {
        // can be called on any thread
        
        // An NSOperation's init method does not have to be thread safe; it's relatively
        // easy to enforce the requirement that the init method is only called by the
        // main thread, or just one single thread.  However, in this case it's easy to
        // make the init method thread safe, so we do that.
        
        // Initialise our numbers property by taking a copy of the incoming
        // numbers array.  Note that we use a copy here.  If you just retain
        // the incoming value then the program will crash because our client
        // passes us an NSMutableArray (which is type compatible with NSArray)
        // and can then mutate it behind our back.
        
        if NSUserDefaults.standardUserDefaults().boolForKey("retainNotCopy") {
            self.numbers = numbers
        } else {
            self.numbers = numbers.copy() as! NSArray
        }
        super.init()
        
        // Set up our sequenceNumber property.  Note that, because we can be called
        // from any thread, we have to use a lock to protect sSequenceNumber (that
        // is, to guarantee that each operation gets a unique sequence number).
        // In this case locking isn't a problem because we do very little within
        // that lock; there's no possibility of deadlock, and the chances of lock
        // contention are slight.
        
        synchronized(AdderOperation.self) {
            struct My {
                static var sSequenceNumber: Int = 0
            }
            self.sequenceNumber = My.sSequenceNumber
            My.sSequenceNumber += 1
        }
        
        self.interNumberDelay = 1.0
    }
    //
    //- (instancetype)initWithNumbers2:(NSArray *)numbers
    //{
    init(numbers2 numbers: NSArray) {
        // IMPORTANT: This is method is not actually used.  It is here because it's a code
        // snippet in the technote, and i wanted to make sure it compiles.
        
        assertionFailure(#function)
        
        self.numbers = numbers.copy() as! NSArray
        super.init()
    }
    
    deinit {
        // can be called on any thread
        
        // Note that we can safely release our properties here, even properties like
        // formatter, which are meant to only be accessed by the operation's thread.
        // That's because -retain and -release are always fully thread safe, even in
        // situations where other methods on an object are not.
        //
        // Of course, the actual work to release the objects is now done by ARC.
    }
    
    override func main() {
        
        // This method is called by a thread that's set up for us by the NSOperationQueue.
        
        assert(!NSThread.isMainThread())
        
        // We latch interNumberDelay at this point so that, if the client changes
        // it after they've queued the operation (something they shouldn't be doing,
        // but hey, we're cautious), we always see a consistent value.
        
        let localInterNumberDelay: NSTimeInterval = self.interNumberDelay
        
        // Set up the formatter.  This is a private property that's only accessed by
        // the operation thread, so we don't have to worry about synchronising access to it.
        
        self.formatter = NSNumberFormatter()
        assert(self.formatter != nil)
        
        self.formatter.numberStyle = .DecimalStyle
        self.formatter.usesGroupingSeparator = true
        
        // Do the heavy lifting (-:
        
        var localTotal: Int = 0
        for number in numbers as! [NSNumber] {
            
            // Check for cancellation.
            
            if self.cancelled {
                break
            }
            
            // Sleep for the inter-number delay.  This makes it easier to
            // test cancellation and so on.
            
            NSThread.sleepForTimeInterval(localInterNumberDelay)
            
            // Do the maths (but they said there'd be no maths!).
            
            localTotal += number.integerValue
        }
        
        // Set our output properties base on the value we calculated.  Our client
        // shouldn't look at these until -isFinished goes to YES (which happens when
        // we return from this method).
        
        self.total = localTotal
        self.formattedTotal = self.formatter.stringFromNumber(localTotal)!
    }
    
    func main2() {
        
        // IMPORTANT: This is method is not actually used.  It is here because it's a code
        // snippet in the technote, and i wanted to make sure it compiles.
        
        assertionFailure(#function)
        
        // This method is called by a thread that's set up for us by the NSOperationQueue.
        
        assert(!NSThread.isMainThread())
        
        // Do the heavy lifting (-:
        
        var total = 0
        for numberObj in self.numbers as! [NSNumber] {
            
            // Check for cancellation.
            
            if self.cancelled {
                break
            }
            
            // Sleep for a second.  This makes it easier to test cancellation
            // and so on.
            
            NSThread.sleepForTimeInterval(1.0)
            
            // Do the maths (but they said there'd be no maths!).
            
            total += numberObj.integerValue
        }
        
        // Set our output properties base on the value we calculated.  Our client
        // shouldn't look at these until -isFinished goes to YES (which happens when
        // we return from this method).
        
        self.formattedTotal = self.formatter.stringFromNumber(total)!
    }
    
}