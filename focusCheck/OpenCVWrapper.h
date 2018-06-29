//
//  OpenCVWrapper.h
//  focusCheck
//
//  Created by 直井翔汰 on 2018/06/27.
//  Copyright © 2018年 直井翔汰. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

@interface OpenCVWrapper: NSObject
+(UIImage *)maskImage:(UIImage *)image topLeftPoint:(CGPoint *)topLeftPoint bottomRightPoint:(CGPoint *)bottomLeftPoint;
+(UIImage *)cannyImage:(UIImage *)image;
//+ (cv::Mat)matWithImage:(UIImage*)image
@end
