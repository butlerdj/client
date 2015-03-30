//
//  KBTextField.m
//  Keybase
//
//  Created by Gabriel on 1/12/15.
//  Copyright (c) 2015 Gabriel Handford. All rights reserved.
//

#import "KBTextField.h"

#import "KBAppearance.h"
#import <GHKit/GHKit.h>
#import "KBLabel.h"

@interface KBNSTextField : NSTextField
@property (weak) id<KBNSTextFieldFocusDelegate> focusDelegate;
@end

@interface KBNSSecureTextField : NSSecureTextField
@property (weak) id<KBNSTextFieldFocusDelegate> focusDelegate;
@end

@interface KBTextField ()
@property NSTextField *textField;
@property NSBox *focusView;
@property BOOL focused;
@property NSTimer *timer;
@end

@implementation KBTextField

- (void)viewInit {
  [self viewInit:NO];
}

- (void)viewInit:(BOOL)secure {
  if (secure) {
    KBNSSecureTextField *textField = [[KBNSSecureTextField alloc] init];
    textField.focusDelegate = self;
    _textField = textField;
  } else {
    KBNSTextField *textField = [[KBNSTextField alloc] init];
    textField.focusDelegate = self;
    _textField = textField;
  }
  _textField.bordered = NO;
  _textField.focusRingType = NSFocusRingTypeNone;
  _textField.font = [NSFont systemFontOfSize:18];
  _textField.lineBreakMode = NSLineBreakByTruncatingHead;
  [self addSubview:_textField];

  // This is fucking crazy but it's the only way
  _timer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(_checkFocused) userInfo:nil repeats:YES];

  _focusView = [[NSBox alloc] init];
  _focusView.borderColor = [KBAppearance.currentAppearance lineColor];
  _focusView.borderWidth = 1;
  _focusView.frame = CGRectMake(0, 0, 0, 1);
  _focusView.borderType = NSLineBorder;
  _focusView.boxType = NSBoxCustom;
  [self addSubview:_focusView];

  YOSelf yself = self;
  self.viewLayout = [YOLayout layoutWithLayoutBlock:^(id<YOLayout> layout, CGSize size) {
    CGFloat y = 0;
    CGSize sizeThatFits = [KBLabel sizeThatFits:size attributedString:[[NSAttributedString alloc] initWithString:@"Pg" attributes:@{NSFontAttributeName: yself.textField.font}]];
    y += [layout setFrame:CGRectMake(0, y, size.width, sizeThatFits.height + 2) view:yself.textField].size.height;
    if (!yself.focusView.hidden) {
      y += ceilf(sizeThatFits.height * 0.2);
      [layout setFrame:CGRectMake(0, y - yself.focusView.frame.size.height, size.width, yself.focusView.frame.size.height) view:yself.focusView];
      y += 2;
    }
    return CGSizeMake(size.width, y);
  }];
}

- (void)dealloc {
  [NSNotificationCenter.defaultCenter removeObserver:self];
  [_timer invalidate];
}

- (NSString *)description {
  return [NSString stringWithFormat:@"%@: %@", self.className, self.text ? self.text : self.placeholder];
}

- (BOOL)becomeFirstResponder {
  return [_textField becomeFirstResponder];
}

- (BOOL)resignFirstResponder {
  return [_textField resignFirstResponder];
}

- (BOOL)acceptsFirstResponder {
  return YES;
}

- (void)textField:(NSTextField *)textField didChangeFocus:(BOOL)focused {
  if (_focused == focused) return;
  _focused = focused;
  //GHDebug(@"Focused: %@ (%@)", @(_focused), self.placeholder);

  _focusView.borderColor = focused ? KBAppearance.currentAppearance.selectColor : KBAppearance.currentAppearance.lineColor;
  CGRect r = _focusView.frame;
  r.size = CGSizeMake(_focusView.frame.size.width, focused ? 2.0 : 1.0);
  _focusView.frame = r;
  [self.focusDelegate textField:self didChangeFocus:focused];
}

- (void)_checkFocused {
  BOOL isFocused = [KBTextField isFocused:_textField];
  if (_focused && !isFocused) {
    [self textField:_textField didChangeFocus:NO];
  } else if (!_focused && isFocused) {
    [self textField:_textField didChangeFocus:YES];
  }
}

- (void)textField:(NSTextField *)textField didChangeEnabled:(BOOL)enabled {
  if (enabled && _focused) {
    _focusView.borderColor = KBAppearance.currentAppearance.selectColor;
  } else if (!enabled && _focused) {
    _focusView.borderColor = KBAppearance.currentAppearance.lineColor;
  }
}

- (void)setText:(NSString *)text {
  _textField.stringValue = text ? text : @"";
}

- (NSMutableDictionary *)attributes {
  if (!_attributes) _attributes = [NSMutableDictionary dictionary];
  return _attributes;
}

- (NSString *)text {
  if ([_textField.stringValue isEqualToString:@""]) return nil;
  return _textField.stringValue;
}

- (NSString *)placeholder {
  return _textField.placeholderString;
}

- (void)setPlaceholder:(NSString *)placeholder {
  _textField.placeholderString = placeholder;
}

+ (BOOL)isFocused:(NSTextField *)textField {
  BOOL isFocused = [(NSTextField *)[textField.cell controlView] currentEditor] != nil && [textField.window isKeyWindow];
  //GHDebug(@"Check focused: %@, %@", textField.placeholderString, @(isFocused));
  return isFocused;

  /*
   id firstResponder = [[NSApp keyWindow] firstResponder];

   if ([firstResponder isKindOfClass:NSText.class]) {
   firstResponder = (id)[(NSText *)firstResponder delegate];
   }

   BOOL isSelf = (firstResponder == self);
   NSString *description = [firstResponder description];
   if ([firstResponder respondsToSelector:@selector(placeholderString)]) description = [firstResponder placeholderString];
   //GHDebug(@"[%@] First responder: %@ (%@); %@", reason, firstResponder, description, @(isSelf));
   return isSelf;
   */
}

@end

@implementation KBSecureTextField

- (void)viewInit {
  [self viewInit:YES];
}

@end

@implementation KBNSTextField

- (BOOL)becomeFirstResponder {
  BOOL responder = [super becomeFirstResponder];
  [self.focusDelegate textField:self didChangeFocus:[KBTextField isFocused:self]];
  return responder;
}

- (BOOL)resignFirstResponder {
  BOOL resigned = [super resignFirstResponder];
  [self.focusDelegate textField:self didChangeFocus:[KBTextField isFocused:self]];
  return resigned;
}

- (void)setEnabled:(BOOL)enabled {
  [super setEnabled:enabled];
  [self.focusDelegate textField:self didChangeEnabled:enabled];
}

- (void)textDidEndEditing:(NSNotification *)notification {
  [super textDidEndEditing:notification];
  [self.focusDelegate textField:self didChangeFocus:[KBTextField isFocused:self]];
}

@end

@implementation KBNSSecureTextField

- (BOOL)becomeFirstResponder {
  [self.focusDelegate textField:self didChangeFocus:[KBTextField isFocused:self]];
  return [super becomeFirstResponder];
}

- (BOOL)resignFirstResponder {
  BOOL resigned = [super resignFirstResponder];
  [self.focusDelegate textField:self didChangeFocus:[KBTextField isFocused:self]];
  return resigned;
}

- (void)setEnabled:(BOOL)enabled {
  [super setEnabled:enabled];
  [self.focusDelegate textField:self didChangeEnabled:enabled];
}

- (void)textDidEndEditing:(NSNotification *)notification {
  [super textDidEndEditing:notification];
  [self.focusDelegate textField:self didChangeFocus:[KBTextField isFocused:self]];
}

@end