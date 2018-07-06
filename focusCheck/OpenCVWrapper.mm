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



+(cv::Mat)threshold:(cv::Mat)image {
    cv::Mat binaryImage;
    cv::threshold(image, binaryImage, 200, 255, CV_THRESH_BINARY);
    return binaryImage;
}


+(UIImage *)sobelImage:(UIImage *)image {
    cv::Mat sobelImage, binaryImage;
    cv::Mat matImage = [self matWithImage: image];
    cv::cvtColor(matImage, matImage, CV_BGR2GRAY);
    cv::threshold(matImage, binaryImage, 200, 255, CV_THRESH_BINARY);
//    [self histgram: matImage];
    //cv::Sobel(binaryImage, sobelImage, <#int ddepth#>, <#int dx#>, <#int dy#>);
    return MatToUIImage(binaryImage);
}

+(void)histgram:(cv::Mat)image {
    
    unsigned char histgram[256] = {0};
    for (int y = 0; y < image.rows; y++) {
        for (int x = 0; x < image.cols; x++) {
            unsigned char s = image.at<unsigned char>(y, x);
            
            histgram[s]++;
        }
    }
    
    printf("\n\n");
    for (int i = 0; i < 256; i++) {
        printf("%d\n", histgram[i]);
    }
    printf("\n\n");
}

+(UIImage *)cannyImage:(UIImage *)image maxValue:(int *)maxValue minValue:(int *) minValue {
    cv::Mat cannyImage, grayImge;
    cv::Mat matImage = [self matWithImage: image];
    cv::cvtColor(matImage, grayImge, CV_BGRA2GRAY);
    grayImge = [self threshold: grayImge.clone()];
//    [self histgram:grayImge];
    std::vector< std::vector<cv::Point> > contours;
    std::vector<cv::Vec4i> hierarchy;
    cv::findContours(grayImge, contours, hierarchy, cv::RETR_EXTERNAL, cv::CHAIN_APPROX_TC89_L1);
    
    if (contours.size() == 0) {
        return image;
    }
    
    std::vector<cv::Point> maxAreaContour;
    double maxArea = cv::contourArea(contours[0], false);
    for (int i = 1; i < contours.size(); i++) {
        if (maxArea < cv::contourArea(contours[i])) {
            maxArea = cv::contourArea(contours[i]);
            maxAreaContour = contours[i];
        }
    }
    
//    cv::polylines(matImage, maxAreaContour, true, cv::Scalar(255, 0, 0), 2);
    cv::Point minP = {1900000, 10000}; //x, y
    cv::Point maxP = {0, 0}; //x, y
    
    //TODO: ROIがx,y, width, height だったので　minP maxP 必要ない　一つのcv::Pointでok
    for (int i = 1 ; i < maxAreaContour.size(); i++) {
        if (minP.x > maxAreaContour[i].x) {
            minP.x = maxAreaContour[i].x;
        }
        if (minP.y > maxAreaContour[i].y) {
            minP.y = maxAreaContour[i].y;
        }
        
        if (maxP.x < maxAreaContour[i].x) {
            maxP.x = maxAreaContour[i].x;
        }
        if (maxP.y < maxAreaContour[i].y) {
            maxP.y = maxAreaContour[i].y;
        }
    }
    //yの値を　光の強い帯部分の下部を見るように設定
    //はみ出さないことを調べる
    if (maxP.x-20 + 200 >= matImage.cols) {
        return image;
    }
    //roi設定
    printf("%d %d %d %d\n", minP.x, minP.y, maxP.x, maxP.y);
    cv::Rect roi(maxP.x-20, 0, 200, matImage.rows-1); // x,y width, height
    printf("%d %d\n", roi.x + roi.width, roi.height);
    printf("%d %d\n", grayImge.cols, grayImge.rows);
//    return MatToUIImage(grayImge);
    cannyImage = matImage.clone();
    cv::Mat4b roiImage = matImage(roi);
    //return MatToUIImage(roiImage);
    cv::Mat1b roiGray;
    cv::Mat4b cannyRoiImage = cannyImage(roi);
    cv::Mat1b cannyRoiImageGRAY;
    cv::Mat4b cannyRoiImageBGRA;
    cv::cvtColor(roiImage, roiGray, CV_BGRA2GRAY);
    cv::Canny(roiGray, cannyRoiImageGRAY, *minValue, *maxValue);
    printf("y:%d x:%d\n", roiImage.rows, roiImage.cols);
    printf("y:%d x:%d\n", cannyRoiImageGRAY.rows, cannyRoiImageGRAY.cols);
//    printf("%d", cannyRoiImage.channels());
    cv::cvtColor(cannyRoiImageGRAY, cannyRoiImageBGRA, CV_GRAY2BGRA);
//    printf("%d", cannyImage.channels());
    printf("y:%d x:%d\n", cannyRoiImageBGRA.rows, cannyRoiImageBGRA.cols);
    
    cv::rectangle(cannyImage, cv::Point(roi.x, roi.y), cv::Point(roi.x+roi.width, roi.y+roi.height), cv::Scalar(255), 3);
    cannyRoiImageBGRA.copyTo(cannyRoiImage);
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
