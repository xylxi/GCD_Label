//
//  GCDLabel.m
//  GCD_Coretext
//
//  Created by Johnil on 13-8-16.
//  Copyright (c) 2013年 Johnil. All rights reserved.
//

#import "GCDLabel.h"

CTTextAlignment CTTextAlignmentFromUITextAlignment(NSTextAlignment alignment) {
	switch (alignment) {
		case NSTextAlignmentLeft:   return kCTLeftTextAlignment;
		case NSTextAlignmentCenter: return kCTCenterTextAlignment;
		case NSTextAlignmentRight:  return kCTRightTextAlignment;
		default:                    return kCTNaturalTextAlignment;
	}
}

@implementation GCDLabel {
    // 正常状态的图片
	UIImageView *labelImageView;
    // 高亮状态的图片
	UIImageView *highlightImageView;
    // 高亮
	BOOL highlighting;
    // 绘制
	CTFrameRef ctframe;
    // 记录匹配字符串的range
    NSRange currentRange;
    // 高亮状态下，各种类型的字符串颜色
	NSMutableDictionary *highlightColor;
    // 正则匹配到的字符串的的range
	NSMutableArray *rangeArr;
    // lines数组
	CFArrayRef lines;
    // 每一行的points的数组
	CGPoint* lineOrigins;
}

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        rangeArr = [[NSMutableArray alloc] init];
        highlightColor = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
                          COLOR_URL,kRegexHighlightViewTypeAccount,
                          COLOR_URL,kRegexHighlightViewTypeURL,
                          COLOR_URL,kRegexHighlightViewTypeTopic,nil];
		labelImageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, frame.size.width, frame.size.height)];
		labelImageView.contentMode = UIViewContentModeScaleAspectFill;
		labelImageView.tag = NSIntegerMin;
		labelImageView.clipsToBounds = YES;
		[self addSubview:labelImageView];

		highlightImageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, frame.size.width, frame.size.height)];
		highlightImageView.contentMode = UIViewContentModeScaleAspectFill;
		highlightImageView.tag = NSIntegerMin;
		highlightImageView.clipsToBounds = YES;
		[self addSubview:highlightImageView];

		self.userInteractionEnabled = YES;
		self.backgroundColor = [UIColor whiteColor];
		_textAlignment = NSTextAlignmentLeft;
		_textColor = [UIColor blackColor];
		_font = [UIFont systemFontOfSize:16];
		_lineSpace = 5;
	}
    return self;
}
- (void)setFrame:(CGRect)frame {
	if (!CGSizeEqualToSize(labelImageView.image.size, frame.size)) {
		labelImageView.image = nil;
		highlightImageView.image = nil;
	}
	labelImageView.frame     = CGRectMake(0, 0, frame.size.width, frame.size.height);
	highlightImageView.frame = CGRectMake(0, 0, frame.size.width, frame.size.height);
	[super setFrame:frame];
}
/**
 *  为匹配到的文字设置颜色
 */
- (NSAttributedString *)highlightText:(NSMutableAttributedString *)coloredString {
    NSString* string = coloredString.string;
    NSRange range = NSMakeRange(0,[string length]);
    NSDictionary* definition = @{kRegexHighlightViewTypeAccount: AccountRegular,
								 kRegexHighlightViewTypeURL:URLRegular,
								 kRegexHighlightViewTypeTopic:TopicRegular};
    for(NSString* key in definition) {
        // 获取正则表达式
        NSString* expression = [definition objectForKey:key];
        // 从整体字符串中找到匹配的字符串数组
        NSArray* matches = [[NSRegularExpression regularExpressionWithPattern:expression
																	  options:NSRegularExpressionDotMatchesLineSeparators
                                                                        error:nil]
							matchesInString:string
							options:0 range:range];
        // 遍历数组
        for(NSTextCheckingResult* match in matches) {
            UIColor* textColor = nil;
            // 不是高亮状态 活着 textColor不等于高亮的对应的颜色
            if(!highlightColor||!(textColor=([highlightColor objectForKey:key])))
                textColor = self.textColor;
            // 在高亮状态下
            // 高亮currentRange存在
            if (currentRange.location!=-1 && NSEqualRanges(currentRange, match.range)) {
                // 设置高亮的文字颜色
                [coloredString addAttribute:(NSString*)kCTForegroundColorAttributeName
									  value:(id)COLOR_URL_CLICK.CGColor
									  range:match.range];
            } else {
                if ([rangeArr indexOfObject:[NSValue valueWithRange:match.range]]==NSIntegerMax) {
                    // 将找到的range，添加到数组中，缓存
                    [rangeArr addObject:[NSValue valueWithRange:match.range]];
                    NSLog(@"%@,%@",[NSValue valueWithRange:match.range],match);
                }
                // 设置正常状态下的文字颜色
                [coloredString addAttribute:(NSString*)kCTForegroundColorAttributeName
									  value:(id)textColor.CGColor
									  range:match.range];
            }
        }
    }
    
    // 返回修改后的AttributedString
    return coloredString;
}

- (void)setText:(NSString *)text{
	if (text==nil || text.length<=0) {
		return;
	}
    
    // 不是高亮、重用时候文字没有改变，labelImageView.image不为nil
	if (!highlighting && [text isEqualToString:_text]&&labelImageView.image!=nil) {
		return;
	}
    // 多线程绘制
	dispatch_async(dispatch_queue_create(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{

		NSString *temp = text;
		_text = text;
        // 开启一个大小为size的位图
		UIGraphicsBeginImageContextWithOptions(self.frame.size, YES, 0);
        // 获取上下文
		CGContextRef context = UIGraphicsGetCurrentContext();
        // 设置setFill和setStroke 颜色
		[self.backgroundColor set];
        // 填充指定CGRect的Fill颜色
		CGContextFillRect(context, CGRectMake(0, 0, self.frame.size.width, self.frame.size.height));
        
        // Coretext坐标翻转为UIKit坐标
		CGContextSetTextMatrix(context,CGAffineTransformIdentity);
		CGContextTranslateCTM(context,0,([self bounds]).size.height);
		CGContextScaleCTM(context,1.0,-1.0);

        // Cell总大小
		CGSize size = self.frame.size;
        // 文本颜色
		UIColor* textColor = self.textColor;
        // 段落颜色
		CGFloat minimumLineHeight = self.font.pointSize,maximumLineHeight = minimumLineHeight+10, linespace = self.lineSpace;
		CTFontRef font = CTFontCreateWithName((__bridge CFStringRef)self.font.fontName, self.font.pointSize,NULL);
		CTLineBreakMode lineBreakMode = kCTLineBreakByWordWrapping;
		CTTextAlignment alignment = CTTextAlignmentFromUITextAlignment(self.textAlignment);
		CTParagraphStyleRef style = CTParagraphStyleCreate((CTParagraphStyleSetting[5]){
			{kCTParagraphStyleSpecifierAlignment, sizeof(alignment), &alignment},
			{kCTParagraphStyleSpecifierMinimumLineHeight,sizeof(minimumLineHeight),&minimumLineHeight},
			{kCTParagraphStyleSpecifierMaximumLineHeight,sizeof(maximumLineHeight),&maximumLineHeight},
			{kCTParagraphStyleSpecifierLineSpacing, sizeof(linespace), &linespace},
			{kCTParagraphStyleSpecifierLineBreakMode,sizeof(CTLineBreakMode),&lineBreakMode}
		},5);
        
        // 为本属性
		NSDictionary* attributes = [NSDictionary dictionaryWithObjectsAndKeys:(__bridge id)font,
									(NSString*)kCTFontAttributeName,
									(__bridge id)textColor.CGColor,
									(NSString*)kCTForegroundColorAttributeName,
									(__bridge id)style,(NSString*)kCTParagraphStyleAttributeName,nil];
        // 绘制的path区域
		CGMutablePathRef path = CGPathCreateMutable();
		CGPathAddRect(path,NULL,CGRectMake(0, 0,(size.width),(size.height)));
        
        // 根据NSMutableAttributedString生成
        NSMutableAttributedString *attributedStr = [[NSMutableAttributedString alloc]
                                                    initWithString:text
                                                    attributes:attributes];
        // 设置特殊字符串的颜色
		CFAttributedStringRef attributedString = (__bridge CFAttributedStringRef)[self highlightText:attributedStr];
		CTFramesetterRef framesetter = CTFramesetterCreateWithAttributedString((CFAttributedStringRef)attributedString);

        // 因为在多线程环境下工作而且Cell会被复用，所以要判断temp是不是还是text
        // 如果不是，说明这个cell在还没有绘制结束就被复用了
		if ([temp isEqualToString:text]) {
            // 生成ctframe
			ctframe = CTFramesetterCreateFrame(framesetter, CFRangeMake(0,CFAttributedStringGetLength(attributedString)),path,NULL);
            // 绘制
			CTFrameDraw(ctframe,context);
            
			CGPathRelease(path);
			CFRelease(style);
			CFRelease(font);
			CFRelease(framesetter);
			[[attributedStr mutableString] setString:@""];
			attributedStr = nil;
            // 获取image
			UIImage *screenShotimage = [UIImage imageWithCGImage:UIGraphicsGetImageFromCurrentImageContext().CGImage
														   scale:[UIScreen mainScreen].scale
													 orientation:UIImageOrientationUp];
            // 关闭上下文
			UIGraphicsEndImageContext();
            // 主线程刷新UI
			dispatch_async(dispatch_get_main_queue(), ^{
				if (highlighting) {
					highlightImageView.image = nil;
					highlightImageView.image = screenShotimage;
				} else {
                    // 再次确认，是不是cell在没有绘制结束，就被重用了，而且重用后文字不一样
					if ([temp isEqualToString:text]&&CGSizeEqualToSize(screenShotimage.size, self.frame.size)) {
						highlightImageView.image = nil;
						labelImageView.image     = nil;
						labelImageView.image     = screenShotimage;
					}
				}
			});
		}
	});
}

/** 获取lines数组和每个line的起始point*/
- (void)loadLines{
	lines = CTFrameGetLines(ctframe);
	lineOrigins = malloc(sizeof(CGPoint)*CFArrayGetCount(lines));
	CTFrameGetLineOrigins(ctframe, CFRangeMake(0,0), lineOrigins);
}
- (void)highlightWord{
	highlighting = YES;
	[self setText:_text];
}
- (void)backToNormal{
	highlighting = NO;
	currentRange = NSMakeRange(-1, -1);
    // 移除高亮iamge
	highlightImageView.image = nil;
}

#pragma mark - touch
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event{
    UITouch* touch = [touches anyObject];
    // 点击的坐标
    CGPoint point = [touch locationInView:self];
    // 为什么要转换为Quartz2D下的坐标
    CGPoint reversePoint = CGPointMake(point.x, self.frame.size.height-point.y);
    
    currentRange = NSMakeRange(-1, -1);
    // 获取lines和lineOrigins
	[self loadLines];
	int count = (int)CFArrayGetCount(lines);
    // 遍历每一个line
    for(CFIndex i = 0; i < count; i++){
        // 当前的line
        CTLineRef line = CFArrayGetValueAtIndex(lines, i);
        // line的起始坐标
        CGPoint origin = lineOrigins[i];
        
        float wordY = origin.y;
        float currentY = reversePoint.y;
        // 前判断这个line是不是点击的line, 如果是在找runs
        if (currentY >=wordY && currentY<=(wordY+self.font.pointSize) ) {
            // 使用 CTLineGetStringIndexForPosition函数来获得用户点击的位置对应 NSAttributedString 字符串上的位置信息（index)
            NSInteger index = CTLineGetStringIndexForPosition(line, reversePoint);
            // 遍历rangeArr
            for (NSValue *obj in rangeArr) {
                // 判断index是否在obj中
                if (NSLocationInRange(index, obj.rangeValue)) {
                    // 获取obj的range的字符串，这就是要设置为高亮的字符串
                    NSString *temp = [self.text substringWithRange:obj.rangeValue];
                    // 再次确认temp是不是要处理成高亮的字符串
                    if ([temp rangeOfString:@"@"].location!=NSNotFound ||
						[temp rangeOfString:@"#"].location!=NSNotFound ||
						[temp rangeOfString:@"http"].location!=NSNotFound) {
                        // 记录range
						currentRange = obj.rangeValue;
                        // 重新绘制
						[self highlightWord];
                    }
                }
            }
        }
    }
}
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event{
	if (highlighting) {
		double delayInSeconds = .2;
		dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
		dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
			[self backToNormal];
		});
		return;
	}
}
- (void)removeFromSuperview{
	if (ctframe) {
		CFRelease(ctframe);
		ctframe = NULL;
	}
	if (lines) {
		CFRelease(lines);
		lines = NULL;
	}
	if (lineOrigins) {
		free(lineOrigins);
	}
	[highlightColor removeAllObjects];
	highlightColor = nil;
	[rangeArr removeAllObjects];
	rangeArr = nil;
	[super removeFromSuperview];
}

@end
