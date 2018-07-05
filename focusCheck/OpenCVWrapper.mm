//
//  OpenCVWrapper.m
//  focusCheck
//
//  Created by 直井翔汰 on 2018/06/27.
//  Copyright © 2018年 直井翔汰. All rights reserved.
//

#import "OpenCVWrapper.h"

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

#import <opencv2/imgcodecs/ios.h>
#import <opencv2/opencv.hpp>

@implementation OpenCVWrapper: NSObject
+(UIImage *)maskImage:(UIImage *)image topLeftPoint:(CGPoint *)topLeftPoint bottomRightPoint:(CGPoint *)bottomRightPoint {
    cv::Mat maskImage, resultImage;
    cv::Mat matImage = [self matWithImage: image];
    printf("rows = %d", matImage.rows);
    maskImage = cv::Mat(matImage.size(), CV_8U, cv::Scalar(0));
    
    // 左上と右下の2点から4点作成（左下と右上）
    
    cv::Point points[4] = { cv::Point(topLeftPoint->x, topLeftPoint->y),
                            cv::Point(topLeftPoint->x, bottomRightPoint->y),
                            cv::Point(bottomRightPoint->x, bottomRightPoint->y),
                            cv::Point(bottomRightPoint->x, topLeftPoint->y)
                          };
    
    for (int i = 0; i < 4; i++) {
        printf("%d: x = %d, y = %d\n", i, points[i].x, points[i].y);
    }
    
    printf("x = %d, y = %d\n", maskImage.cols, maskImage.rows);
    
    cv::fillConvexPoly(maskImage, points, 4, cv::Scalar(255), CV_AA);
    return MatToUIImage(maskImage);
}

+(UIImage *)sobelImage:(UIImage *)image {
    cv::Mat sobelImage, binaryImage;
    cv::Mat matImage = [self matWithImage: image];
    cv::cvtColor(matImage, matImage, CV_BGR2GRAY);
    cv::threshold(matImage, binaryImage, 124, 255, CV_THRESH_BINARY | CV_THRESH_OTSU);
    
    //cv::Sobel(binaryImage, sobelImage, <#int ddepth#>, <#int dx#>, <#int dy#>);
    return MatToUIImage(sobelImage);
}

+(UIImage *)cannyImage:(UIImage *)image maxValue:(int *)maxValue minValue:(int *) minValue {
    cv::Mat cannyImage, grayImge;
    cv::Mat matImage = [self matWithImage: image];
    cv::cvtColor(matImage, grayImge, CV_BGR2GRAY);
    cv::Canny(grayImge, cannyImage, *minValue, *maxValue);
    
    return MatToUIImage(cannyImage);
}

+ (cv::Mat)matWithImage:(UIImage*)image
{
    // 画像の回転を補正する（内蔵カメラで撮影した画像などでおかしな方向にならないようにする）
    UIImage* correctImage = image;
    UIGraphicsBeginImageContext(correctImage.size);
    [correctImage drawInRect:CGRectMake(0, 0, correctImage.size.width, correctImage.size.height)];
    correctImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    // UIImage -> cv::Mat
    cv::Mat mat;

    UIImageToMat(correctImage, mat);
    return mat;
}


@end
