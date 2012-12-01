//
//  iConsole.m
//
//  Version 1.4
//
//  Created by Nick Lockwood on 20/12/2010.
//  Copyright 2010 Charcoal Design
//
//  Distributed under the permissive zlib License
//  Get the latest version from either of these locations:
//
//  http://charcoaldesign.co.uk/source/cocoa#iconsole
//  https://github.com/nicklockwood/iConsole
//
//  This software is provided 'as-is', without any express or implied
//  warranty.  In no event will the authors be held liable for any damages
//  arising from the use of this software.
//
//  Permission is granted to anyone to use this software for any purpose,
//  including commercial applications, and to alter it and redistribute it
//  freely, subject to the following restrictions:
//
//  1. The origin of this software must not be misrepresented; you must not
//  claim that you wrote the original software. If you use this software
//  in a product, an acknowledgment in the product documentation would be
//  appreciated but is not required.
//
//  2. Altered source versions must be plainly marked as such, and must not be
//  misrepresented as being the original software.
//
//  3. This notice may not be removed or altered from any source distribution.
//

#import "iConsole.h"
#import <stdarg.h>
#import <string.h>

#import "NimbusCore.h"
#import "NIOverviewView.h"
#import "NIOverviewPageView.h"
#import "YIEdgePanGestureRecognizer.h"


#define EDITFIELD_HEIGHT 28
#define ACTION_BUTTON_WIDTH 28


@interface iConsole() <UITextFieldDelegate, UIActionSheetDelegate>

@property (nonatomic, strong) UITextView *consoleView;
@property (nonatomic, strong) UITextField *inputField;
@property (nonatomic, strong) UIButton *actionButton;
@property (nonatomic, strong) NSMutableArray *log;
@property (nonatomic, assign) BOOL animating;

- (void)saveSettings;

@end


@implementation iConsole

#pragma mark -
#pragma mark Private methods

static void exceptionHandler(NSException *exception)
{
	[iConsole crash:@"%@", exception.name];
	[iConsole crash:@"%@", exception.reason];
	[iConsole crash:@"%@", exception.callStackSymbols];

	[iConsole save];
}

+ (void)load
{
    //initialise the console
    [iConsole performSelectorOnMainThread:@selector(sharedConsole) withObject:nil waitUntilDone:NO];
}

- (UIWindow *)mainWindow
{
    UIApplication *app = [UIApplication sharedApplication];
    if ([app.delegate respondsToSelector:@selector(window)])
    {
        return [app.delegate window];
    }
    else
    {
        return [app keyWindow];
    }
}

- (void)setConsoleText
{
	NSString *text = _infoString;
    
    if ([[self mainWindow] isKindOfClass:[iConsoleWindow class]]) {
        int touches = (TARGET_IPHONE_SIMULATOR ? _simulatorTouchesToShow: _deviceTouchesToShow);
        if (touches > 0 && touches < 11)
        {
            text = [text stringByAppendingFormat:@"\nSwipe down with %i finger%@ to hide console", touches, (touches != 1)? @"s": @""];
        }
        else if (TARGET_IPHONE_SIMULATOR ? _simulatorShakeToShow: _deviceShakeToShow)
        {
            text = [text stringByAppendingString:@"\nShake device to hide console"];
        }
    }
	
	text = [text stringByAppendingString:@"\n--------------------------------------\n"];
	text = [text stringByAppendingString:[_log componentsJoinedByString:@"\n"]];
	_consoleView.text = text;
	
	[_consoleView scrollRangeToVisible:NSMakeRange(_consoleView.text.length, 0)];
}

- (void)resetLog
{
	self.log = [NSMutableArray arrayWithObjects:@"> ", nil];
	[self setConsoleText];
}

- (void)saveSettings
{
    if (_saveLogToDisk)
    {
        [[NSUserDefaults standardUserDefaults] setObject:_log forKey:@"iConsoleLog"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

- (BOOL)findAndResignFirstResponder:(UIView *)view
{
    if ([view isFirstResponder])
	{
        [view resignFirstResponder];
        return YES;     
    }
    for (UIView *subview in view.subviews)
	{
        if ([self findAndResignFirstResponder:subview])
        {
			return YES;
		}
    }
    return NO;
}

- (void)infoAction
{
	[self findAndResignFirstResponder:[self mainWindow]];
	
	UIActionSheet *sheet = [[[UIActionSheet alloc] initWithTitle:@""
														delegate:self
											   cancelButtonTitle:@"Cancel"
										  destructiveButtonTitle:@"Clear Log"
											   otherButtonTitles:@"Send by Email", nil] autorelease];

	sheet.actionSheetStyle = UIActionSheetStyleBlackOpaque;
	[sheet showInView:self.view];
}

- (CGAffineTransform)viewTransform
{
	CGFloat angle = 0;
	switch ([UIApplication sharedApplication].statusBarOrientation)
    {
        case UIInterfaceOrientationPortrait:
            angle = 0;
            break;
		case UIInterfaceOrientationPortraitUpsideDown:
			angle = M_PI;
			break;
		case UIInterfaceOrientationLandscapeLeft:
			angle = -M_PI_2;
			break;
		case UIInterfaceOrientationLandscapeRight:
			angle = M_PI_2;
			break;
	}
	return CGAffineTransformMakeRotation(angle);
}

- (CGRect)onscreenFrame
{
	return [UIScreen mainScreen].applicationFrame;
}

- (CGRect)offscreenFrame
{
	CGRect frame = [self onscreenFrame];
	switch ([UIApplication sharedApplication].statusBarOrientation)
    {
		case UIInterfaceOrientationPortrait:
			frame.origin.y = frame.size.height;
			break;
		case UIInterfaceOrientationPortraitUpsideDown:
			frame.origin.y = -frame.size.height;
			break;
		case UIInterfaceOrientationLandscapeLeft:
			frame.origin.x = frame.size.width;
			break;
		case UIInterfaceOrientationLandscapeRight:
			frame.origin.x = -frame.size.width;
			break;
	}
	return frame;
}

- (void)showConsole
{
	if (!_animating && self.view.superview == nil)
	{
        [self setConsoleText];
        
		[self findAndResignFirstResponder:[self mainWindow]];
        
        _animating = YES;
        
        [[self mainWindow].rootViewController presentViewController:[iConsole sharedConsole] animated:YES completion:^{
            _animating = NO;
            [self findAndResignFirstResponder:[self mainWindow]];
        }];
	}
}

- (void)consoleShown
{
	_animating = NO;
	[self findAndResignFirstResponder:[self mainWindow]];
}

- (void)hideConsole
{
	if (!_animating && self.view.superview != nil)
	{
		[self findAndResignFirstResponder:[self mainWindow]];
		
		_animating = YES;
    
    [[self mainWindow].rootViewController dismissViewControllerAnimated:YES completion:^{
      _animating = NO;
      [[[iConsole sharedConsole] view] removeFromSuperview];
    }];
    
	}
}

- (void)keyboardWillShow:(NSNotification *)notification
{	
	CGRect frame = [[notification.userInfo valueForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
	CGFloat duration = [[notification.userInfo valueForKey:UIKeyboardAnimationDurationUserInfoKey] floatValue];
	UIViewAnimationCurve curve = [[notification.userInfo valueForKey:UIKeyboardAnimationCurveUserInfoKey] intValue];
	
	[UIView beginAnimations:nil context:NULL];
	[UIView setAnimationBeginsFromCurrentState:YES];
	[UIView setAnimationDuration:duration];
	[UIView setAnimationCurve:curve];
	
	CGRect bounds = [self onscreenFrame];
	switch ([UIApplication sharedApplication].statusBarOrientation)
    {
		case UIInterfaceOrientationPortrait:
			bounds.size.height -= frame.size.height;
			break;
		case UIInterfaceOrientationPortraitUpsideDown:
			bounds.origin.y += frame.size.height;
			bounds.size.height -= frame.size.height;
			break;
		case UIInterfaceOrientationLandscapeLeft:
			bounds.size.width -= frame.size.width;
			break;
		case UIInterfaceOrientationLandscapeRight:
			bounds.origin.x += frame.size.width;
			bounds.size.width -= frame.size.width;
			break;
	}
	self.view.frame = bounds;
	
	[UIView commitAnimations];
}

- (void)keyboardWillHide:(NSNotification *)notification
{
	CGFloat duration = [[notification.userInfo valueForKey:UIKeyboardAnimationDurationUserInfoKey] floatValue];
	UIViewAnimationCurve curve = [[notification.userInfo valueForKey:UIKeyboardAnimationCurveUserInfoKey] intValue];
	
	[UIView beginAnimations:nil context:NULL];
	[UIView setAnimationBeginsFromCurrentState:YES];
	[UIView setAnimationDuration:duration];
	[UIView setAnimationCurve:curve];
	
	self.view.frame = [self onscreenFrame];	
	
	[UIView commitAnimations];
}

- (void)logOnMainThread:(NSString *)message
{
	[_log addObject:[@"> " stringByAppendingString:message]];
	if ([_log count] > _maxLogItems)
	{
		[_log removeObjectAtIndex:0];
	}
    
    if (self.view.superview)
    {
        [self setConsoleText];
    }
}

#pragma mark -
#pragma mark UITextFieldDelegate methods

- (void)textFieldDidEndEditing:(UITextField *)textField
{
	if (![textField.text isEqualToString:@""])
	{
		[iConsole log:textField.text];
		[_delegate handleConsoleCommand:textField.text];
		textField.text = @"";
	}
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
	[textField resignFirstResponder];
	return YES;
}

- (BOOL)textFieldShouldClear:(UITextField *)textField
{
	return YES;
}


#pragma mark -
#pragma mark UIActionSheetDelegate methods

- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex
{
	if (buttonIndex == actionSheet.destructiveButtonIndex)
	{
		[iConsole clear];
	}
	else if (buttonIndex != actionSheet.cancelButtonIndex)
	{
        if ([MFMailComposeViewController canSendMail]) {

            NSString* subject = [NSString stringWithFormat:@"%@ (ver %@ b%@ / %@ %@)",
                                 [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"],
                                 [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"],
                                 [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"],
                                 [UIDevice currentDevice].systemName,
                                 [UIDevice currentDevice].systemVersion
                                 ];
            
            MFMailComposeViewController *mailVC = [[MFMailComposeViewController alloc] init];
            mailVC.mailComposeDelegate = self;
            
            [mailVC setToRecipients:(_logSubmissionEmail ? [NSArray arrayWithObject:_logSubmissionEmail] : nil)];
            [mailVC setSubject:subject];
            
            [mailVC setMessageBody:[_log componentsJoinedByString:@"\n"] isHTML:NO];
            
            [self presentModalViewController:mailVC animated:YES];
            
        }
	}
}

#pragma mark -
#pragma mark MFMailComposeViewControllerDelegate

- (void)mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error
{
    [self dismissModalViewControllerAnimated:YES];
}

#pragma mark -
#pragma mark Life cycle

+ (iConsole *)sharedConsole
{
    @synchronized(self)
    {
        static iConsole *sharedConsole = nil;
        if (sharedConsole == nil)
        {
            sharedConsole = [[self alloc] init];
        }
        return sharedConsole; 
    }
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
	if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]))
	{
        NSSetUncaughtExceptionHandler(&exceptionHandler);
        
        _enabled = YES;
        _logLevel = iConsoleLogLevelInfo;
        _saveLogToDisk = YES;
        _maxLogItems = 1000;
        _delegate = nil;
        
        _simulatorTouchesToShow = 2;
        _deviceTouchesToShow = 3;
        _simulatorShakeToShow = YES;
        _deviceShakeToShow = NO;
        
        self.infoString = @"iConsole: Copyright © 2010 Charcoal Design";
        self.inputPlaceholderString = @"Enter command...";
        self.logSubmissionEmail = nil;
        
        self.backgroundColor = [UIColor blackColor];
        self.textColor = [UIColor whiteColor];
        
        [self resetLog];
        
        [[NSUserDefaults standardUserDefaults] synchronize];
        self.log = [NSMutableArray arrayWithArray:[[NSUserDefaults standardUserDefaults] objectForKey:@"iConsoleLog"]];
        
        // comment-out: iConsole will not handle auto-saving
//        if (&UIApplicationDidEnterBackgroundNotification != NULL)
//        {
//            [[NSNotificationCenter defaultCenter] addObserver:self
//                                                     selector:@selector(saveSettings)
//                                                         name:UIApplicationDidEnterBackgroundNotification
//                                                       object:nil];
//        }
//
//        [[NSNotificationCenter defaultCenter] addObserver:self
//                                                 selector:@selector(saveSettings)
//                                                     name:UIApplicationWillTerminateNotification
//                                                   object:nil];
        
	}
	return self;
}

- (void)viewDidLoad
{
    
#ifdef DEBUG
    // NIOverviewView (only works in DEBUG build)
    CGRect overviewFrame = self.view.bounds;
    overviewFrame.size.height = 60;
    
    NIOverviewView* overviewView = [[NIOverviewView alloc] initWithFrame:overviewFrame];
    overviewView.backgroundColor = [UIColor clearColor];
    
    [overviewView addPageView:[NIOverviewMemoryPageView page]];
    [overviewView addPageView:[NIOverviewDiskPageView page]];
    [overviewView addPageView:[NIOverviewMemoryCachePageView page]];
//    [overviewView addPageView:[NIOverviewConsoleLogPageView page]];
//    [overviewView addPageView:[NIOverviewMaxLogLevelPageView page]];
    [self.view addSubview:overviewView];
#else
    CGRect overviewFrame = CGRectZero;
#endif
    
    self.view.clipsToBounds = YES;
	self.view.backgroundColor = _backgroundColor;
	self.view.autoresizesSubviews = YES;
    
    CGRect consoleFrame = self.view.bounds;
    consoleFrame.origin.y = overviewFrame.size.height;
    consoleFrame.size.height = self.view.bounds.size.height-overviewFrame.size.height;
    
    _consoleView = [[UITextView alloc] initWithFrame:consoleFrame];
    _consoleView.clipsToBounds = YES;
	_consoleView.font = [UIFont fontWithName:@"Courier" size:12];
	_consoleView.textColor = _textColor;
	_consoleView.backgroundColor = [UIColor clearColor];
	_consoleView.editable = NO;
	_consoleView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    _consoleView.indicatorStyle = UIScrollViewIndicatorStyleWhite;
	[self setConsoleText];
	[self.view insertSubview:_consoleView belowSubview:overviewView];
	
	self.actionButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [_actionButton setTitle:@"⚙" forState:UIControlStateNormal];
    [_actionButton setTitleColor:_textColor forState:UIControlStateNormal];
    [_actionButton setTitleColor:[_textColor colorWithAlphaComponent:0.5f] forState:UIControlStateHighlighted];
    _actionButton.titleLabel.font = [_actionButton.titleLabel.font fontWithSize:ACTION_BUTTON_WIDTH];
	_actionButton.frame = CGRectMake(self.view.frame.size.width - ACTION_BUTTON_WIDTH - 5,
                                   self.view.frame.size.height - EDITFIELD_HEIGHT - 5,
                                   ACTION_BUTTON_WIDTH, EDITFIELD_HEIGHT);
	[_actionButton addTarget:self action:@selector(infoAction) forControlEvents:UIControlEventTouchUpInside];
	_actionButton.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleLeftMargin;
	[self.view addSubview:_actionButton];
	
	if (_delegate)
	{
		_inputField = [[UITextField alloc] initWithFrame:CGRectMake(5, self.view.frame.size.height - EDITFIELD_HEIGHT - 5,
                                                                    self.view.frame.size.width - 15 - ACTION_BUTTON_WIDTH,
                                                                    EDITFIELD_HEIGHT)];
		_inputField.borderStyle = UITextBorderStyleRoundedRect;
		_inputField.font = [UIFont fontWithName:@"Courier" size:12];
		_inputField.autocapitalizationType = UITextAutocapitalizationTypeNone;
		_inputField.autocorrectionType = UITextAutocorrectionTypeNo;
		_inputField.returnKeyType = UIReturnKeyDone;
		_inputField.enablesReturnKeyAutomatically = NO;
		_inputField.clearButtonMode = UITextFieldViewModeWhileEditing;
		_inputField.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
		_inputField.placeholder = _inputPlaceholderString;
		_inputField.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth;
		_inputField.delegate = self;
		[self.view addSubview:_inputField];
    
		consoleFrame.size.height -= EDITFIELD_HEIGHT + 10;
		_consoleView.frame = consoleFrame;
		
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(keyboardWillShow:)
													 name:UIKeyboardWillShowNotification
												   object:nil];
		
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(keyboardWillHide:)
													 name:UIKeyboardWillHideNotification
												   object:nil];
	}

	[self.consoleView scrollRangeToVisible:NSMakeRange(self.consoleView.text.length, 0)];
}

- (void)viewDidUnload
{
	[[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillHideNotification object:nil];
	
	self.consoleView = nil;
	self.inputField = nil;
	self.actionButton = nil;
    
    [super viewDidUnload];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
	
    [_infoString release];
    [_inputPlaceholderString release];
    [_logSubmissionEmail release];
    [_backgroundColor release];
    [_textColor release];
	[_consoleView release];
	[_inputField release];
	[_actionButton release];
	[_log release];
    
	[super ah_dealloc];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
    return YES;
}

- (BOOL)shouldAutorotate
{
    return YES;
}

#pragma mark -
#pragma mark Public methods

+ (void)log:(NSString *)format arguments:(va_list)argList
{	
	NSString *message = [[[NSString alloc] initWithFormat:format arguments:argList] autorelease];
	NSLog(@"%@", message);
	
    if ([self sharedConsole].enabled)
    {
        if ([NSThread currentThread] == [NSThread mainThread])
        {	
            [[self sharedConsole] logOnMainThread:message];
        }
        else
        {
            [[self sharedConsole] performSelectorOnMainThread:@selector(logOnMainThread:)
                                                   withObject:message waitUntilDone:NO];
        }
    }
}

+ (void)log:(NSString *)format, ...
{
    if ([self sharedConsole].logLevel >= iConsoleLogLevelNone)
    {
        va_list argList;
        va_start(argList,format);
        [self log:format arguments:argList];
        va_end(argList);
    }
}

+ (void)info:(NSString *)format, ...
{
    if ([self sharedConsole].logLevel >= iConsoleLogLevelInfo)
    {
        va_list argList;
        va_start(argList, format);
        [self log:[@"INFO: " stringByAppendingString:format] arguments:argList];
        va_end(argList);
    }
}

+ (void)warn:(NSString *)format, ...
{
	if ([self sharedConsole].logLevel >= iConsoleLogLevelWarning)
    {
        va_list argList;
        va_start(argList, format);
        [self log:[@"WARNING: " stringByAppendingString:format] arguments:argList];
        va_end(argList);
    }
}

+ (void)error:(NSString *)format, ...
{
    if ([self sharedConsole].logLevel >= iConsoleLogLevelError)
    {
        va_list argList;
        va_start(argList, format);
        [self log:[@"ERROR: " stringByAppendingString:format] arguments:argList];
        va_end(argList);
    }
}

+ (void)crash:(NSString *)format, ...
{
    if ([self sharedConsole].logLevel >= iConsoleLogLevelCrash)
    {
        va_list argList;
        va_start(argList, format);
        [self log:[@"CRASH: " stringByAppendingString:format] arguments:argList];
        va_end(argList);
    }
}

+ (void)clear
{
	[[iConsole sharedConsole] resetLog];
}

+ (void)save
{
	[[iConsole sharedConsole] saveSettings];
}

+ (void)show
{
	[[iConsole sharedConsole] showConsole];
}

+ (void)hide
{
	[[iConsole sharedConsole] hideConsole];
}

@end


@implementation iConsoleWindow

- (void)setRootViewController:(UIViewController *)rootViewController
{
    // remove gesture from old viewController
    for (UIGestureRecognizer* gesture in self.rootViewController.view.gestureRecognizers) {
        if ([gesture isKindOfClass:[YIEdgePanGestureRecognizer class]]) {
            [self.rootViewController.view removeGestureRecognizer:gesture];
            break;
        }
    }
    
    [super setRootViewController:rootViewController];
    
    YIEdgePanGestureRecognizer* edgePanGesture = [[YIEdgePanGestureRecognizer alloc] initWithTarget:self action:@selector(handleEdgePanGesture:)];
    edgePanGesture.edgeInsets = UIEdgeInsetsMake(0, 0, 20, 0);
    [self.rootViewController.view addGestureRecognizer:edgePanGesture];
}

- (void)handleEdgePanGesture:(YIEdgePanGestureRecognizer*)gesture
{
    if (gesture.state == UIGestureRecognizerStateBegan) {
        
        if ([iConsole sharedConsole].view.superview == nil)
        {
            [iConsole show];
        }
        else
        {
            [iConsole hide];
        }
        
    }
}

- (void)sendEvent:(UIEvent *)event
{
	if ([iConsole sharedConsole].enabled && event.type == UIEventTypeTouches)
	{
		NSSet *touches = [event allTouches];
		if ([touches count] == (TARGET_IPHONE_SIMULATOR ? [iConsole sharedConsole].simulatorTouchesToShow: [iConsole sharedConsole].deviceTouchesToShow))
		{
			BOOL allUp = YES;
			BOOL allDown = YES;
			BOOL allLeft = YES;
			BOOL allRight = YES;
			
			for (UITouch *touch in touches)
			{
				if ([touch locationInView:self].y <= [touch previousLocationInView:self].y)
				{
					allDown = NO;
				}
				if ([touch locationInView:self].y >= [touch previousLocationInView:self].y)
				{
					allUp = NO;
				}
				if ([touch locationInView:self].x <= [touch previousLocationInView:self].x)
				{
					allLeft = NO;
				}
				if ([touch locationInView:self].x >= [touch previousLocationInView:self].x)
				{
					allRight = NO;
				}
			}
			
			switch ([UIApplication sharedApplication].statusBarOrientation)
            {
				case UIInterfaceOrientationPortrait:
                {
					if (allUp)
					{
						[iConsole show];
						return;
					}
					else if (allDown)
					{
						[iConsole hide];
						return;
					}
					break;
                }
				case UIInterfaceOrientationPortraitUpsideDown:
                {
					if (allDown)
					{
						[iConsole show];
						return;
					}
					else if (allUp)
					{
						[iConsole hide];
						return;
					}
					break;
                }
				case UIInterfaceOrientationLandscapeLeft:
                {
					if (allRight)
					{
						[iConsole show];
						return;
					}
					else if (allLeft)
					{
						[iConsole hide];
						return;
					}
					break;
                }
				case UIInterfaceOrientationLandscapeRight:
                {
					if (allLeft)
					{
						[iConsole show];
						return;
					}
					else if (allRight)
					{
						[iConsole hide];
						return;
					}
					break;
                }
			}
		}
	}
	return [super sendEvent:event];
}

- (void)motionEnded:(UIEventSubtype)motion withEvent:(UIEvent *)event {
	
    if ([iConsole sharedConsole].enabled &&
        (TARGET_IPHONE_SIMULATOR ? [iConsole sharedConsole].simulatorShakeToShow: [iConsole sharedConsole].deviceShakeToShow))
    {
        if (event.type == UIEventTypeMotion && event.subtype == UIEventSubtypeMotionShake)
        {
            if ([iConsole sharedConsole].view.superview == nil)
            {
                [iConsole show];
            }
            else
            {
                [iConsole hide];
            }
        }
	}
	[super motionEnded:motion withEvent:event];
}

@end
