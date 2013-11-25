#import "EZSideMenu.h"
/////////////////start
BOOL EZSideMenuUIKitIsFlatMode() // 是否支持扁平
{
    static BOOL             isUIKitFlatMode = NO;
    static dispatch_once_t  onceToken;

    dispatch_once(&onceToken, ^{
            if (floor(NSFoundationVersionNumber) > 993.0) {
                // If your app is running in legacy mode, tintColor will be nil - else it must be set to some color.
                if (UIApplication.sharedApplication.keyWindow) {
                    isUIKitFlatMode = [UIApplication.sharedApplication.delegate.window performSelector:@selector(tintColor)] != nil;
                } else {
                    // Possible that we're called early on (e.g. when used in a Storyboard). Adapt and use a temporary window.
                    isUIKitFlatMode = [[UIWindow new] performSelector:@selector(tintColor)] != nil;
                }
            }
        });
    return isUIKitFlatMode;
}

////////////////////end

///////
@implementation UIViewController (EZSideMenu)

- (void)re_displayController:(UIViewController *)controller frame:(CGRect)frame
{
    [self addChildViewController:controller];
    controller.view.frame = frame;
    [self.view addSubview:controller.view];
    [controller didMoveToParentViewController:self];
}

- (void)re_hideController:(UIViewController *)controller
{
    [controller willMoveToParentViewController:nil];
    [controller.view removeFromSuperview];
    [controller removeFromParentViewController];
}

- (EZSideMenu *)sideMenuViewController
{
    UIViewController *iter = self.parentViewController;

    while (iter) {
        if ([iter isKindOfClass:[EZSideMenu class]]) {
            return (EZSideMenu *)iter;
        } else if (iter.parentViewController && (iter.parentViewController != iter)) {
            iter = iter.parentViewController;
        } else {
            iter = nil;
        }
    }

    return nil;
}

@end
///////

@interface EZSideMenu ()

@property (strong, nonatomic) UIImageView    *backgroundImageView;
@property (assign, nonatomic) BOOL           visible;
@property (assign, nonatomic) CGPoint        originalPoint;
@property (strong, nonatomic) UIButton       *contentButton; // 主界面上add上去的按钮
@property (assign, nonatomic) BOOL        isSideFromEdge;


@end

@implementation EZSideMenu

- (id)init
{
    self = [super init];

    if (self) {
        [self commonInit];
    }

    return self;
}

- (id)initWithCoder:(NSCoder *)decoder
{
    self = [super initWithCoder:decoder];

    if (self) {
        [self commonInit];
    }

    return self;
}

- (void)commonInit
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    self.wantsFullScreenLayout = YES;
#pragma clang diagnostic pop
    _animationDuration = 0.3f;
    _panGestureEnabled = YES;

    _scaleContentView = YES;
    _contentViewScaleValue = 0.7f;

    _scaleBackgroundImageView = YES;
    _backgroundImageViewScaleValue = 1.7f;
    _scaleMenuViewController = YES;
    _menuViewControllerScaleValue = 1.5;
    _gradientMenuViewController = YES;

    _onlySlideFromEdge = NO;
    _slideEdgeValue = 25.f;
    
    _parallaxEnabled = YES;
    _parallaxMenuMinimumRelativeValue = @(-15);
    _parallaxMenuMaximumRelativeValue = @(15);

    _parallaxContentMinimumRelativeValue = @(-25);
    _parallaxContentMaximumRelativeValue = @(25);
}

- (id)initWithContentViewController:(UIViewController *)contentViewController menuViewController:(UIViewController *)menuViewController
{
    self = [self init];

    if (self) {
        _contentViewController = contentViewController;
        _menuViewController = menuViewController;
    }

    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    // 打开抽屉后主界面的中心点偏移
    if (!_contentViewInLandscapeOffsetCenterX) {
        _contentViewInLandscapeOffsetCenterX = CGRectGetHeight(self.view.frame) + 30.f;
    }

    if (!_contentViewInPortraitOffsetCenterX) {
        _contentViewInPortraitOffsetCenterX = CGRectGetWidth(self.view.frame) + 30.f;
    }

    self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.backgroundImageView = ({
            UIImageView *imageView = [[UIImageView alloc] initWithFrame:self.view.bounds];
            imageView.image = self.backgroundImage;
            imageView.contentMode = UIViewContentModeScaleAspectFill;
            imageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            imageView;
        });
    self.contentButton = ({
            UIButton *button = [[UIButton alloc] initWithFrame:CGRectNull];
            [button addTarget:self action:@selector(hideMenuViewController) forControlEvents:UIControlEventTouchUpInside];
            button;
        });

    [self.view addSubview:self.backgroundImageView];
    [self re_displayController:self.menuViewController frame:self.view.frame];
    [self re_displayController:self.contentViewController frame:self.view.frame];

    if (self.gradientMenuViewController) {
        self.menuViewController.view.alpha = 0;
    }

    if (self.scaleBackgroundImageView) {
        self.backgroundImageView.transform = CGAffineTransformMakeScale(self.backgroundImageViewScaleValue, self.backgroundImageViewScaleValue);
    }

    [self addMenuViewControllerMotionEffects];

    if (self.panGestureEnabled) {
        UIPanGestureRecognizer *panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panGestureRecognized:)];
        [self.view addGestureRecognizer:panGestureRecognizer];
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
}

#pragma mark -

- (void)presentMenuViewController
{
    //打开抽屉前初始化动画参数
    if (self.scaleBackgroundImageView) {
        self.backgroundImageView.transform = CGAffineTransformIdentity;
        self.backgroundImageView.frame = self.view.bounds;
        self.backgroundImageView.transform = CGAffineTransformMakeScale(self.backgroundImageViewScaleValue, self.backgroundImageViewScaleValue);
    }

    if (self.scaleMenuViewController) {
        self.menuViewController.view.transform = CGAffineTransformIdentity;
        self.menuViewController.view.frame = self.view.bounds;
        self.menuViewController.view.transform = CGAffineTransformMakeScale(self.menuViewControllerScaleValue, self.menuViewControllerScaleValue);
    }

    if (self.gradientMenuViewController) {
        self.menuViewController.view.alpha = 0;
    }

    if ([self.delegate conformsToProtocol:@protocol(EZSideMenuDelegate)] && [self.delegate respondsToSelector:@selector(sideMenu:willShowMenuViewController:)]) {
        [self.delegate sideMenu:self willShowMenuViewController:self.menuViewController];
    }

    [self showMenuViewController];
}

- (void)showMenuViewController
{
    [self.view.window endEditing:YES];//退出键盘等
    [self addContentButton];

    [UIView animateWithDuration:self.animationDuration animations:^{
        if (self.scaleContentView) {
            self.contentViewController.view.transform = CGAffineTransformMakeScale(self.contentViewScaleValue, self.contentViewScaleValue);
        } else {
            self.contentViewController.view.transform = CGAffineTransformIdentity;
        }

        self.contentViewController.view.center = CGPointMake((UIDeviceOrientationIsLandscape([UIDevice currentDevice].orientation) ? self.contentViewInLandscapeOffsetCenterX : self.contentViewInPortraitOffsetCenterX), self.contentViewController.view.center.y);

        if (self.scaleBackgroundImageView) {
            self.backgroundImageView.transform = CGAffineTransformIdentity;
        }

        if (self.scaleMenuViewController) {
            self.menuViewController.view.transform = CGAffineTransformIdentity;
        }

        if (self.gradientMenuViewController) {
            self.menuViewController.view.alpha = 1.f;
        }
    } completion:^(BOOL finished) {
        [self addContentViewControllerMotionEffects];

        if (!self.visible && [self.delegate conformsToProtocol:@protocol(EZSideMenuDelegate)] && [self.delegate respondsToSelector:@selector(sideMenu:didShowMenuViewController:)]) {
            [self.delegate sideMenu:self didShowMenuViewController:self.menuViewController];
        }

        self.visible = YES;
    }];

    [self updateStatusBar];
}

- (void)hideMenuViewController
{
    [self.view.window endEditing:YES];
    if ([self.delegate conformsToProtocol:@protocol(EZSideMenuDelegate)] && [self.delegate respondsToSelector:@selector(sideMenu:willHideMenuViewController:)]) {
        [self.delegate sideMenu:self willHideMenuViewController:self.menuViewController];
    }

    [self.contentButton removeFromSuperview];                           // 记得移除按钮

    [[UIApplication sharedApplication] beginIgnoringInteractionEvents]; // 忽略所有事件
    [UIView animateWithDuration:self.animationDuration animations:^{
        self.contentViewController.view.transform = CGAffineTransformIdentity;
        self.contentViewController.view.frame = self.view.bounds;

        if (self.scaleBackgroundImageView) {
            self.backgroundImageView.transform = CGAffineTransformMakeScale(self.backgroundImageViewScaleValue, self.backgroundImageViewScaleValue);
        }

        if (self.scaleMenuViewController) {
            self.menuViewController.view.transform = CGAffineTransformMakeScale(self.menuViewControllerScaleValue, self.menuViewControllerScaleValue);
        }

        if (self.gradientMenuViewController) {
            self.menuViewController.view.alpha = 0;
        }

        if (self.parallaxEnabled) {
            IF_IOS7_OR_GREATER(
                for (UIMotionEffect * effect in self.contentViewController.view.motionEffects) {
                    [self.contentViewController.view removeMotionEffect:effect];
                }

                );
        }
    } completion:^(BOOL finished) {
        [[UIApplication sharedApplication] endIgnoringInteractionEvents];

        if (!self.visible && [self.delegate conformsToProtocol:@protocol(EZSideMenuDelegate)] && [self.delegate respondsToSelector:@selector(sideMenu:didHideMenuViewController:)]) {
            [self.delegate sideMenu:self didHideMenuViewController:self.menuViewController];
        }
    }];
    self.visible = NO;
    [self updateStatusBar];
}

- (void)addContentButton
{
    if (self.contentButton.superview) {
        return;
    }

    self.contentButton.autoresizingMask = UIViewAutoresizingNone;
    self.contentButton.frame = self.contentViewController.view.bounds;
    self.contentButton.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.contentViewController.view addSubview:self.contentButton];
}
#pragma mark - animation

- (void)flashMenu{
    // Animate to deappear
    __typeof (&*self) __weak weakSelf = self;
    self.menuViewController.view.transform = CGAffineTransformScale(self.menuViewController.view.transform, 0.9, 0.9);
    [UIView animateWithDuration:0.5 animations:^{
        weakSelf.menuViewController.view.transform = CGAffineTransformIdentity;
    }];
    [UIView animateWithDuration:0.6 animations:^{
        weakSelf.menuViewController.view.alpha = 0;
    }];

    [UIView animateWithDuration:0.6 animations:^{
        weakSelf.menuViewController.view.alpha = 1;
    }];
}
#pragma mark -
#pragma mark Motion effects

- (void)addMenuViewControllerMotionEffects
{
    if (self.parallaxEnabled) {
        IF_IOS7_OR_GREATER(
            for (UIMotionEffect *effect in self.menuViewController.view.motionEffects) {
                [self.menuViewController.view removeMotionEffect:effect];
            }

            UIInterpolatingMotionEffect *interpolationHorizontal = [[UIInterpolatingMotionEffect alloc]initWithKeyPath:@"center.x" type:UIInterpolatingMotionEffectTypeTiltAlongHorizontalAxis];
            interpolationHorizontal.minimumRelativeValue = self.parallaxMenuMinimumRelativeValue;
            interpolationHorizontal.maximumRelativeValue = self.parallaxMenuMaximumRelativeValue;

            UIInterpolatingMotionEffect *interpolationVertical = [[UIInterpolatingMotionEffect alloc]initWithKeyPath:@"center.y" type:UIInterpolatingMotionEffectTypeTiltAlongVerticalAxis];
            interpolationVertical.minimumRelativeValue = self.parallaxMenuMinimumRelativeValue;
            interpolationVertical.maximumRelativeValue = self.parallaxMenuMaximumRelativeValue;

            [self.menuViewController.view addMotionEffect:interpolationHorizontal];
            [self.menuViewController.view addMotionEffect:interpolationVertical];
            );
    }
}

- (void)addContentViewControllerMotionEffects
{
    if (self.parallaxEnabled) {
        IF_IOS7_OR_GREATER(
            for (UIMotionEffect *effect in self.contentViewController.view.motionEffects) {
                [self.contentViewController.view removeMotionEffect:effect];
            }

            [UIView animateWithDuration:0.2 animations:^{
                UIInterpolatingMotionEffect *interpolationHorizontal = [[UIInterpolatingMotionEffect alloc] initWithKeyPath:@"center.x" type:UIInterpolatingMotionEffectTypeTiltAlongHorizontalAxis];
                interpolationHorizontal.minimumRelativeValue = self.parallaxContentMinimumRelativeValue;
                interpolationHorizontal.maximumRelativeValue = self.parallaxContentMaximumRelativeValue;

                UIInterpolatingMotionEffect *interpolationVertical = [[UIInterpolatingMotionEffect alloc] initWithKeyPath:@"center.y" type:UIInterpolatingMotionEffectTypeTiltAlongVerticalAxis];
                interpolationVertical.minimumRelativeValue = self.parallaxContentMinimumRelativeValue;
                interpolationVertical.maximumRelativeValue = self.parallaxContentMaximumRelativeValue;

                [self.contentViewController.view addMotionEffect:interpolationHorizontal];
                [self.contentViewController.view addMotionEffect:interpolationVertical];
            }];
            );
    }
}



#pragma mark -
#pragma mark Gesture recognizer

- (void)panGestureRecognized:(UIPanGestureRecognizer *)recognizer
{
//    CGPoint startPoint = [recognizer locationInView:self.view];
//    NSLog(@"%@",NSStringFromCGPoint(startPoint));
    if (self.onlySlideFromEdge &&!self.visible) {
        if (recognizer.state == UIGestureRecognizerStateBegan) {
            CGPoint startPoint = [recognizer locationInView:self.contentViewController.view];
            if (startPoint.x < self.slideEdgeValue) {
                self.isSideFromEdge = YES;
            }else{
                self.isSideFromEdge = NO;
            }
        }
        if (!self.isSideFromEdge) {
            return;
        }
    }

    
    
    if ([self.delegate conformsToProtocol:@protocol(EZSideMenuDelegate)] && [self.delegate respondsToSelector:@selector(sideMenu:didRecognizePanGesture:)]) {
        [self.delegate sideMenu:self didRecognizePanGesture:recognizer];
    }

    if (!self.panGestureEnabled) {
        return;
    }

    CGPoint point = [recognizer translationInView:self.view];

    if (recognizer.state == UIGestureRecognizerStateBegan) {
        if (!self.visible && [self.delegate conformsToProtocol:@protocol(EZSideMenuDelegate)] && [self.delegate respondsToSelector:@selector(sideMenu:willShowMenuViewController:)]) {
            [self.delegate sideMenu:self willShowMenuViewController:self.menuViewController];
        }

        self.originalPoint = self.contentViewController.view.frame.origin;
        self.menuViewController.view.transform = CGAffineTransformIdentity;

        if (self.scaleBackgroundImageView) {
            self.backgroundImageView.transform = CGAffineTransformIdentity;
            self.backgroundImageView.frame = self.view.bounds;
        }

        if (self.scaleContentView) {
            self.backgroundImageView.transform = CGAffineTransformIdentity;
            self.menuViewController.view.frame = self.view.bounds;
        }

        [self addContentButton];
        [self.view.window endEditing:YES];
    }

    if ((recognizer.state == UIGestureRecognizerStateBegan) || (recognizer.state == UIGestureRecognizerStateChanged)) {
        CGFloat delta = self.visible ? (point.x + self.originalPoint.x) / self.originalPoint.x : point.x / self.view.frame.size.width;

        //        CGFloat contentViewScale = self.scaleContentView ? 1 - ((1 - self.contentViewScaleValue) * delta) : 1;
        CGFloat contentViewScale = 1 - ((1 - self.contentViewScaleValue) * delta);
        CGFloat backgroundViewScale = self.backgroundImageViewScaleValue - (0.7f * delta);
        CGFloat menuViewScale = self.menuViewControllerScaleValue - (0.5f * delta);

        if (self.gradientMenuViewController) {
            self.menuViewController.view.alpha = delta;
        }

        if (self.scaleBackgroundImageView) {
            self.backgroundImageView.transform = CGAffineTransformMakeScale(backgroundViewScale, backgroundViewScale);
        }

        if (self.scaleMenuViewController) {
            self.menuViewController.view.transform = CGAffineTransformMakeScale(menuViewScale, menuViewScale);
        }

        if (self.scaleBackgroundImageView) {
            if (backgroundViewScale < 1) {
                self.backgroundImageView.transform = CGAffineTransformIdentity;
            }
        }

        if (contentViewScale > 1) {
            if (!self.visible) {
                self.contentViewController.view.transform = CGAffineTransformIdentity;
            }
            self.contentViewController.view.frame = self.view.bounds;
        } else {
            self.contentViewController.view.transform = self.scaleContentView?CGAffineTransformMakeScale(contentViewScale, contentViewScale):CGAffineTransformIdentity;
            self.contentViewController.view.transform = CGAffineTransformTranslate(self.contentViewController.view.transform, self.visible ? point.x * 0.8 : point.x, 0);
        }

        [self updateStatusBar];
    }

    if (recognizer.state == UIGestureRecognizerStateEnded) {
        if ([recognizer velocityInView:self.view].x > 0) {//返回速度适量
            [self showMenuViewController];
        } else {
            [self hideMenuViewController];
        }
    }
}

#pragma mark -
#pragma mark Setters

- (void)setBackgroundImage:(UIImage *)backgroundImage
{
    _backgroundImage = backgroundImage;

    if (self.backgroundImageView) {
        self.backgroundImageView.image = backgroundImage;
    }
}

- (void)setContentViewController:(UIViewController *)contentViewController
{
    if (!_contentViewController) {
        _contentViewController = contentViewController;
        return;
    }

    CGRect              frame = _contentViewController.view.frame;
    CGAffineTransform   transform = _contentViewController.view.transform;
    [self re_hideController:_contentViewController];
    _contentViewController = contentViewController;
    [self re_displayController:contentViewController frame:self.view.frame];
    contentViewController.view.transform = transform;
    contentViewController.view.frame = frame;

    [self addContentViewControllerMotionEffects];
}

- (void)setContentViewController:(UIViewController *)contentViewController animated:(BOOL)animated
{
    if (!animated) {
        [self setContentViewController:contentViewController];
    } else {
        contentViewController.view.alpha = 0;
        [self.contentViewController.view addSubview:contentViewController.view];
        [UIView animateWithDuration:self.animationDuration animations:^{
            contentViewController.view.alpha = 1;
        } completion:^(BOOL finished) {
            [contentViewController.view removeFromSuperview];
            [self setContentViewController:contentViewController];
        }];
    }
}

- (void)setMenuViewController:(UIViewController *)menuViewController
{
    if (!_menuViewController) {
        _menuViewController = menuViewController;
        return;
    }

    [self re_hideController:_menuViewController];
    _menuViewController = menuViewController;
    [self re_displayController:menuViewController frame:self.view.frame];

    [self addMenuViewControllerMotionEffects];
    [self.view bringSubviewToFront:self.contentViewController.view];
}

#pragma mark -
#pragma mark Rotation handler

- (BOOL)shouldAutorotate
{
    return self.contentViewController.shouldAutorotate;
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    if (self.visible) {
        self.contentViewController.view.transform = CGAffineTransformIdentity;
        self.contentViewController.view.frame = self.view.bounds;
        self.contentViewController.view.transform = CGAffineTransformMakeScale(self.contentViewScaleValue, self.contentViewScaleValue);
        self.contentViewController.view.center = CGPointMake((UIDeviceOrientationIsLandscape([UIDevice currentDevice].orientation) ? self.contentViewInLandscapeOffsetCenterX : self.contentViewInPortraitOffsetCenterX), self.contentViewController.view.center.y);
    }
}

#pragma mark -
#pragma mark Status bar appearance management

- (void)updateStatusBar
{
    // ios7刷新状态栏
    if ([self respondsToSelector:@selector(setNeedsStatusBarAppearanceUpdate)]) {
        [UIView animateWithDuration:0.3f animations:^{
            [self performSelector:@selector(setNeedsStatusBarAppearanceUpdate)];
        }];
    }
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    UIStatusBarStyle statusBarStyle = UIStatusBarStyleDefault;

    IF_IOS7_OR_GREATER(
        statusBarStyle = self.visible ? self.menuViewController.preferredStatusBarStyle : self.contentViewController.preferredStatusBarStyle;

        if (self.contentViewController.view.frame.origin.y > 10) {
            statusBarStyle = self.menuViewController.preferredStatusBarStyle;
        } else {
            statusBarStyle = self.contentViewController.preferredStatusBarStyle;
        }

        );
    return statusBarStyle;
}

- (BOOL)prefersStatusBarHidden
{
    BOOL statusBarHidden = NO;

    IF_IOS7_OR_GREATER(
        statusBarHidden = self.visible ? self.menuViewController.prefersStatusBarHidden : self.contentViewController.prefersStatusBarHidden;

        if (self.contentViewController.view.frame.origin.y > 10) {
            statusBarHidden = self.menuViewController.prefersStatusBarHidden;
        } else {
            statusBarHidden = self.contentViewController.prefersStatusBarHidden;
        }

        );
    return statusBarHidden;
}

- (UIStatusBarAnimation)preferredStatusBarUpdateAnimation
{
    UIStatusBarAnimation statusBarAnimation = UIStatusBarAnimationNone;

    IF_IOS7_OR_GREATER(
        statusBarAnimation = self.visible ? self.menuViewController.preferredStatusBarUpdateAnimation : self.contentViewController.preferredStatusBarUpdateAnimation;

        if (self.contentViewController.view.frame.origin.y > 10) {
            statusBarAnimation = self.menuViewController.preferredStatusBarUpdateAnimation;
        } else {
            statusBarAnimation = self.contentViewController.preferredStatusBarUpdateAnimation;
        }

        );
    return statusBarAnimation;
}

@end