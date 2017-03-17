//
//  LFZoomingView.m
//  LFImagePickerController
//
//  Created by LamTsanFeng on 2017/3/16.
//  Copyright © 2017年 LamTsanFeng. All rights reserved.
//

#import "LFZoomingView.h"
#import "UIView+LFFrame.h"

#import <AVFoundation/AVFoundation.h>

/** 编辑功能 */
#import "LFDrawView.h"
#import "LFSplashView.h"
#import "LFStickerView.h"

@interface LFZoomingView ()

@property (nonatomic, weak) UIImageView *imageView;

/** 绘画 */
@property (nonatomic, weak) LFDrawView *drawView;
/** 贴图 */
@property (nonatomic, weak) LFStickerView *stickerView;
/** 模糊（马赛克、高斯模糊） */
@property (nonatomic, weak) LFSplashView *splashView;

/** 代理 */
@property (nonatomic ,weak) id delegate;

/** 记录编辑层是否可控 */
@property (nonatomic, assign) BOOL editEnable;
@property (nonatomic, assign) BOOL drawViewEnable;
@property (nonatomic, assign) BOOL stickerViewEnable;
@property (nonatomic, assign) BOOL splashViewEnable;

@end

@implementation LFZoomingView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self customInit];
    }
    return self;
}

- (void)customInit
{
    self.backgroundColor = [UIColor clearColor];
    self.contentMode = UIViewContentModeScaleAspectFit;
    self.editEnable = YES;
    
    UIImageView *imageView = [[UIImageView alloc] initWithFrame:self.bounds];
    imageView.backgroundColor = [UIColor clearColor];
    imageView.contentMode = UIViewContentModeScaleAspectFit;
    [self addSubview:imageView];
    self.imageView = imageView;
    
    /** 涂抹 - 最底层 */
    LFSplashView *splashView = [[LFSplashView alloc] initWithFrame:self.bounds];
    /** 默认不能涂抹 */
    splashView.userInteractionEnabled = NO;
    [self addSubview:splashView];
    self.splashView = splashView;
    
    /** 绘画 */
    LFDrawView *drawView = [[LFDrawView alloc] initWithFrame:self.bounds];
    /** 默认不能触发绘画 */
    drawView.userInteractionEnabled = NO;
    [self addSubview:drawView];
    self.drawView = drawView;
    
    /** 贴图 */
    LFStickerView *stickerView = [[LFStickerView alloc] initWithFrame:self.bounds];
    /** 禁止后，贴图将不能拖到，设计上，贴图是永远可以拖动的 */
//    stickerView.userInteractionEnabled = NO;
    [self addSubview:stickerView];
    self.stickerView = stickerView;
}

- (void)setImage:(UIImage *)image
{
    _image = image;
    CGRect imageViewRect = AVMakeRectWithAspectRatioInsideRect(image.size, self.frame);
    self.size = imageViewRect.size;
    
    /** 子控件更新 */
    [[self subviews] enumerateObjectsUsingBlock:^(__kindof UIView * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        obj.frame = self.bounds;
    }];
    
    [self.imageView setImage:image];
    /** 创建马赛克模糊 */
    [self.splashView setImage:image mosaicLevel:10];
}

- (void)scaleSize:(CGSize)size zoomScale:(CGFloat)zoomScale
{
    self.width -= size.width*zoomScale;
    self.height -= size.height*zoomScale;
    
    /** 子控件更新 */
    [[self subviews] enumerateObjectsUsingBlock:^(__kindof UIView * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        /** 计算缩放比例 */
        CGFloat scaleX = (obj.width-size.width)/obj.width;
        CGFloat scaleY = (obj.height-size.height)/obj.height;
        obj.transform = CGAffineTransformScale(obj.transform, scaleX, scaleY);
        obj.origin = CGPointZero;
//        obj.width -= size.width;
//        obj.height -= size.height;
    }];
}

#pragma mark - LFEdittingProtocol

- (void)setEditDelegate:(id<LFPhotoEditDelegate>)editDelegate
{
    _delegate = editDelegate;
    /** 设置代理回调 */
    __weak typeof(self) weakSelf = self;
    
    /** 绘画 */
    _drawView.drawBegan = ^{
        if ([weakSelf.delegate respondsToSelector:@selector(lf_photoEditDrawBegan)]) {
            [weakSelf.delegate lf_photoEditDrawBegan];
        }
    };
    
    _drawView.drawEnded = ^{
        if ([weakSelf.delegate respondsToSelector:@selector(lf_photoEditDrawEnded)]) {
            [weakSelf.delegate lf_photoEditDrawEnded];
        }
    };
    
    /** 贴图 */
    _stickerView.tapEnded = ^(UIView *view, LFStickerViewType type, BOOL isActive){
        if ([weakSelf.delegate respondsToSelector:@selector(lf_photoEditstickerDidSelectView:isActive:)]) {
            [weakSelf.delegate lf_photoEditstickerDidSelectView:view isActive:isActive];
        }
    };
    
    /** 模糊 */
    _splashView.splashBegan = ^{
        if ([weakSelf.delegate respondsToSelector:@selector(lf_photoEditSplashBegan)]) {
            [weakSelf.delegate lf_photoEditSplashBegan];
        }
    };
    
    _splashView.splashEnded = ^{
        if ([weakSelf.delegate respondsToSelector:@selector(lf_photoEditSplashEnded)]) {
            [weakSelf.delegate lf_photoEditSplashEnded];
        }
    };
    
}

- (id<LFPhotoEditDelegate>)editDelegate
{
    return _delegate;
}

/** 禁用其他功能 */
- (void)photoEditEnable:(BOOL)enable
{
    if (_editEnable != enable) {
        _editEnable = enable;
        if (enable) {
            _drawView.userInteractionEnabled = _drawViewEnable;
            _splashView.userInteractionEnabled = _splashViewEnable;
            _stickerView.userInteractionEnabled = _stickerViewEnable;
        } else {
            _drawViewEnable = _drawView.userInteractionEnabled;
            _splashViewEnable = _splashView.userInteractionEnabled;
            _stickerViewEnable = _stickerView.userInteractionEnabled;
            _drawView.userInteractionEnabled = NO;
            _splashView.userInteractionEnabled = NO;
            _stickerView.userInteractionEnabled = NO;
        }
    }
}

#pragma mark - 绘画功能
/** 启用绘画功能 */
- (void)setDrawEnable:(BOOL)drawEnable
{
    _drawView.userInteractionEnabled = drawEnable;
}
- (BOOL)drawEnable
{
    return _drawView.userInteractionEnabled;
}

- (BOOL)drawCanUndo
{
    return _drawView.canUndo;
}
- (void)drawUndo
{
    [_drawView undo];
}

#pragma mark - 贴图功能
/** 取消激活贴图 */
- (void)stickerDeactivated
{
    [LFStickerView LFStickerViewUnAcive];
}

/** 创建贴图 */
- (void)createStickerImage:(UIImage *)image
{
    [_stickerView createImage:image];
}

#pragma mark - 文字功能
/** 创建文字 */
- (void)createStickerText:(NSString *)text
{
    if (text.length) {
        [_stickerView createText:text];
    }
}

#pragma mark - 模糊功能
/** 启用模糊功能 */
- (void)setSplashEnable:(BOOL)splashEnable
{
    _splashView.userInteractionEnabled = splashEnable;
}
- (BOOL)splashEnable
{
    return _splashView.userInteractionEnabled;
}
/** 是否可撤销 */
- (BOOL)splashCanUndo
{
    return _splashView.canUndo;
}
/** 撤销模糊 */
- (void)splashUndo
{
    [_splashView undo];
}

- (void)setSplashState:(BOOL)splashState
{
    if (splashState) {
        _splashView.state = LFSplashStateType_Blurry;
    } else {
        _splashView.state = LFSplashStateType_Mosaic;
    }
}

- (BOOL)splashState
{
    return _splashView.state == LFSplashStateType_Blurry;
}

@end
