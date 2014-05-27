//
//  AKCameraTextView.m
//  TaoVideo
//
//  Created by lihejun on 14-3-18.
//  Copyright (c) 2014年 taovideo. All rights reserved.
//

#import "AKCameraTextView.h"

@implementation AKCameraTextView

#pragma mark - Accessors

@synthesize placeholder = _placeholder;
@synthesize placeholderTextColor = _placeholderTextColor;

- (void)setText:(NSString *)string {
    [super setText:string];
    [self setNeedsDisplay];
}


- (void)insertText:(NSString *)string {
    [super insertText:string];
    [self setNeedsDisplay];
}


- (void)setAttributedText:(NSAttributedString *)attributedText {
    [super setAttributedText:attributedText];
    [self setNeedsDisplay];
}


- (void)setPlaceholder:(NSString *)string {
    if ([string isEqual:_placeholder]) {
        return;
    }
    
    _placeholder = string;
    [self setNeedsDisplay];
}


- (void)setContentInset:(UIEdgeInsets)contentInset {
    [super setContentInset:contentInset];
    [self setNeedsDisplay];
}


- (void)setFont:(UIFont *)font {
    [super setFont:font];
    [self setNeedsDisplay];
}


- (void)setTextAlignment:(NSTextAlignment)textAlignment {
    [super setTextAlignment:textAlignment];
    [self setNeedsDisplay];
}


#pragma mark - NSObject

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UITextViewTextDidChangeNotification object:self];
}


#pragma mark - UIView

- (id)initWithCoder:(NSCoder *)aDecoder {
    if ((self = [super initWithCoder:aDecoder])) {
        [self initialize];
    }
    return self;
}


- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        [self initialize];
    }
    return self;
}


- (void)drawRect:(CGRect)rect {
    [super drawRect:rect];
    
    if (self.text.length == 0 && self.placeholder) {
        rect = [self placeholderRectForBounds:self.bounds];
        
        UIFont *font = self.font ? self.font : self.typingAttributes[NSFontAttributeName];
        
        // Draw the text
        [self.placeholderTextColor set];
        [self.placeholder drawInRect:rect withFont:font lineBreakMode:NSLineBreakByTruncatingTail alignment:self.textAlignment];
    }
}


#pragma mark - Placeholder
#define verticalOffset 8.0
- (CGRect)placeholderRectForBounds:(CGRect)bounds {
    // Inset the rect
    CGRect rect = UIEdgeInsetsInsetRect(bounds, self.contentInset);
    /* NOT Compatiable for ios6
     if (self.typingAttributes) {
     NSParagraphStyle *style = self.typingAttributes[NSParagraphStyleAttributeName];
     if (style) {
     rect.origin.x += style.headIndent;
     rect.origin.y += style.firstLineHeadIndent;
     }
     }
     */
    rect.origin.y += verticalOffset;
    return rect;
}


#pragma mark - Private

- (void)initialize {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(textChanged:) name:UITextViewTextDidChangeNotification object:self];
    
    self.placeholderTextColor = [UIColor colorWithWhite:0.702f alpha:1.0f];
}


- (void)textChanged:(NSNotification *)notification {
    [self setNeedsDisplay];
}

@end
